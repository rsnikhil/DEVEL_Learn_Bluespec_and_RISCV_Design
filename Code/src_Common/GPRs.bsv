// Copyright (c) 2023-2024 Rishiyur S. Nikhil.  All Rights Reserved.

package GPRs;

// ****************************************************************
// This is a 2-read-port register file of 32 registers.
// Register 0 ('x0') always reads as 0.
// Polymorphic: register-width ix 'xlen' (instantiated with 32 for RV32, 64 for RV64)

// ****************************************************************
// Imports from libraries

import RegFile :: *;
import Vector  :: *;

// ----------------
// Local imports

import Arch :: *;

// ****************************************************************
// Interface for GPRs

interface GPRs_IFC #(numeric type xlen);                           // \blatex{GPRs_IFC}
   method Bit #(xlen) read_rs1 (Bit #(5) rs1);
   method Bit #(xlen) read_rs2 (Bit #(5) rs2);
   method Action      write_rd (Bit #(5) rd, Bit #(xlen) rd_val);
                                                                         // \belide{3}
   // For debugger
   method Bit #(xlen) read_dm  (Bit #(5) rs);
   method Action      write_dm (Bit #(5) rd, Bit #(xlen) rd_val);        // \eelide
endinterface                                                       // \elatex{GPRs_IFC}

// ================================================================
// Two implementations of a GPR module

// ----------------------------------------------------------------
// GPRs module; first version
// BSV schedule: register-reads happen "before" register-write
// i.e., in case of concurrent (same-clock) read and write to same index,
// the "read" reads the old value and the "write" writes a new value
// that is available on the subsequent clock.

module mkGPRs (GPRs_IFC #(xlen));                                    // \blatex{mkGPRs}
   RegFile #(Bit #(5), Bit #(xlen)) rf <- mkRegFileFull;

   // ================================================================
   // Initialization
   Reg #(Bit #(6)) rg_init_index <- mkReg (0);

   Bool initialized = (rg_init_index [5] == 1'b1);

   rule rl_init (! initialized);
      rf.upd (truncate (rg_init_index), 0);
      rg_init_index <= rg_init_index + 1;
      if (rg_init_index == 31)
	 $display ("GPRs: initialized to 0");
   endrule

   // ================================================================

   method Bit #(xlen) read_rs1 (Bit #(5) rs1) if (initialized);
      return ((rs1 == 0) ? 0 : rf.sub (rs1));
   endmethod

   method Bit #(xlen) read_rs2 (Bit #(5) rs2) if (initialized);
      return ((rs2 == 0) ? 0 : rf.sub (rs2));
   endmethod

   method Action write_rd (Bit #(5) rd, Bit #(xlen) rd_val) if (initialized);
      rf.upd (rd, rd_val);
   endmethod
                                                                         // \belide{3}
   // For debugger
   method Bit #(xlen) read_dm  (Bit #(5) rs) if (initialized);
      return ((rs == 0) ? 0 : rf.sub (rs));
   endmethod

   method Action write_dm (Bit #(5) rd, Bit #(xlen) rd_val) if (initialized);
      rf.upd (rd, rd_val);
   endmethod                                                             // \eelide
endmodule                                                            // \elatex{mkGPRs}

// ----------------
// A monomorphic version synthesized into Verilog

(* synthesize *)                                         // \blatex{mkGPRs_synth}
module mkGPRs_synth (GPRs_IFC #(XLEN));
   let ifc <- mkGPRs;
   return ifc;
endmodule                                                // \elatex{mkGPRs_synth}

// ****************************************************************
// Interface for Scoreboard

// The scoreboard is a vector of 1-bit values indicating which of the
// 32 registers are "busy". scoreboard[X] is 1 when there is an older
// instruction in the downstream pipes that is expected to write into
// register X.

typedef  Vector #(32, Bit #(1))  Scoreboard;

interface Scoreboard_IFC;
   interface Reg #(Scoreboard) port0;
   interface Reg #(Scoreboard) port1;
endinterface

// ================================================================
// Two implementations of a scoreboard module

// ----------------------------------------------------------------
// Scoreboard module, first version

// Uses an ordinary register.
// Register-read (whether port0 or port1) schedule before
// register-write (whether port0 or port1).

module mkScoreboard (Scoreboard_IFC);
   Reg #(Scoreboard) rg <- mkReg (replicate (0));
   interface port0 = rg;
   interface port1 = rg;
endmodule

// ****************************************************************
// GPR logging (for formal verification, tracing, debugging)
// Records the most recent Rd-write, Rs1-read and Rs2-read
//    Writes: the actual Rd value is available in the GPRs
//    Reads:  we record the actual value read

interface GPR_Logging_IFC #(numeric type xlen);
   method Action log_rd_write (Bit #(64) inum, Bit #(5) rd);
   method Action log_rs1_read (Bit #(64) inum, Bit #(5) rs1, Bit #(xlen) val);
   method Action log_rs2_read (Bit #(64) inum, Bit #(5) rs2, Bit #(xlen) val);
endinterface

// ================================================================

module mkGPR_Logging (GPR_Logging_IFC #(xlen));
   RegFile #(Bit #(5), Bit #(64))   rf_inum_wr <- mkRegFileFull;

   // For recording reads, use two regfiles, since possibly two reads per cycle
   // The one with the larger inum is the most recent
   RegFile #(Bit #(5), Bit #(64))   rf_inum_rd_rs1 <- mkRegFileFull;
   RegFile #(Bit #(5), Bit #(xlen)) rf_val_rd_rs1  <- mkRegFileFull;

   RegFile #(Bit #(5), Bit #(64))   rf_inum_rd_rs2 <- mkRegFileFull;
   RegFile #(Bit #(5), Bit #(xlen)) rf_val_rd_rs2  <- mkRegFileFull;

   method Action log_rd_write (Bit #(64) inum, Bit #(5) rd);
      rf_inum_wr.upd (rd, inum);
   endmethod

   method Action log_rs1_read (Bit #(64) inum, Bit #(5) rs1, Bit #(xlen) val);
      rf_inum_rd_rs1.upd (rs1, inum);
      rf_val_rd_rs1.upd (rs1, val);
   endmethod

   method Action log_rs2_read (Bit #(64) inum, Bit #(5) rs2, Bit #(xlen) val);
      rf_inum_rd_rs2.upd (rs2, inum);
      rf_val_rd_rs2.upd (rs2, val);
   endmethod
endmodule

// ----------------
// A monomorphic version synthesized into Verilog

(* synthesize *)
module mkGPR_Logging_synth (GPR_Logging_IFC #(XLEN));
   let ifc <- mkGPR_Logging;
   return ifc;
endmodule

// ****************************************************************

endpackage
