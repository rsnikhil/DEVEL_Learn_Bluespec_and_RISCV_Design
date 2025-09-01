// Copyright (c) 2025 Rishiyur S. Nikhil.  All Rights Reserved.

package GPRs_b;

// ****************************************************************
// This is a 2-read-port, 1-write-port register file of 32 registers.
// Register 0 ('x0') always reads as 0.
// Polymorphic: register-width ix 'xlen' (instantiated with 32 for RV32, 64 for RV64)

// ****************************************************************
// Imports from libraries

import RegFile :: *;
import Vector  :: *;

// ----------------
// Local imports

import Utils       :: *;
import Arch        :: *;
import Inter_Stage :: *;

// ****************************************************************
// Interface for GPRs

interface GPRs_IFC #(numeric type xlen);                           // \blatex{GPRs_IFC}
   // Result tuple is: (stall, rs1_val, rs2_val)
   method ActionValue #(Tuple3 #(Bool, Bit #(xlen), Bit #(xlen)))
          gpr_access (File flog,
		      // Info from instr in forward path
		      Bool has_rs1, Bit #(5) rs1,
		      Bool has_rs2, Bit #(5) rs2,
		      Bool has_rd,  Bit #(5) rd,
		      // Writeback info
		      Bool wb_valid, RW_from_Retire wb);
   // For debugger                                                       // \belide{3}
   method Bit #(xlen) read_dm  (Bit #(5) rs);
   method Action      write_dm (Bit #(5) rd, Bit #(xlen) rd_val);        // \eelide
endinterface                                                       // \elatex{GPRs_IFC}

// ****************************************************************
// Module implementing GPRs

// TODO: we use XLEN here because wb.data has size XLEN
//       need to parameterize RW_from_Retire with #(xlen) instead of fixed XLEN

module mkGPRs (GPRs_IFC #(xlen))                                    // \blatex{mkGPRs}
   provisos (Add #(xlen, 0, XLEN));
   // The actual registers for GPRs
   RegFile #(Bit #(5), Bit #(xlen)) rf <- mkRegFileFull;

   // Scoreboard for GPRs
   Reg #(Vector #(32, Bit #(1))) rg_scoreboard <- mkReg (replicate (0));

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
   // BEHAVIOR

   function ActionValue #(Tuple3 #(Bool, Bit #(xlen), Bit #(xlen)))
            fav_gpr_access (File flog,
			    // Info from instr in forward path
			    Bool has_rs1, Bit #(5) rs1,
			    Bool has_rs2, Bit #(5) rs2,
			    Bool has_rd,  Bit #(5) rd,
			    // Writeback info
			    Bool wb_valid, RW_from_Retire wb);
      actionvalue
	 // Read rs1, rs2 (harmless if rs1,rs2 are bogus)
	 let rs1_val = rf.sub (rs1);
	 let rs2_val = rf.sub (rs2);

	 let scoreboard = rg_scoreboard;

	 // Writeback: update scoreboard and GPR
	 if (wb_valid) begin
	    scoreboard [wb.rd] = 0;

	    if (wb.commit)
	       rf.upd (wb.rd, wb.data);
                                                                            // \belide{12}
	    // ---------------- DEBUG
	    wr_log (flog, $format ("CPU.WB:"));
	    wr_log (flog, fshow_RW_from_Retire (wb));
	    ftrace (flog, wb.xtra.inum, wb.xtra.pc, wb.xtra.instr, "WB", $format (""));
                                                                            // \eelide
	 end

	 // Get final values of rs1 and rs2, using wb.data if relevant (bypass)
	 if (has_rs1 && (rs1 == wb.rd) && wb_valid && wb.commit)
	    rs1_val = wb.data;
	 if (has_rs2 && (rs2 == wb.rd) && wb_valid && wb.commit)
	    rs2_val = wb.data;

	 // Compute stall-due-to-scoreboard
	 let stall_rs1 = (has_rs1 && scoreboard [rs1] != 0);
	 let stall_rs2 = (has_rs2 && scoreboard [rs2] != 0);
	 let stall_rd  = (has_rd  && scoreboard [rd]  != 0);
	 let stall     = stall_rs1 || stall_rs2 || stall_rd;

	 // Forward path: update scoreboard
	 if ((! stall) && has_rd)
	    scoreboard [rd] = 1;
	 rg_scoreboard <= scoreboard;

	 return tuple3 (stall, rs1_val, rs2_val);
      endactionvalue
   endfunction

   // ----------------------------------------------------------------
   // INTERFACE

   method ActionValue #(Tuple3 #(Bool, Bit #(xlen), Bit #(xlen)))
          gpr_access (File flog,
		      // Info from instr in forward path
		      Bool has_rs1, Bit #(5) rs1,
		      Bool has_rs2, Bit #(5) rs2,
		      Bool has_rd,  Bit #(5) rd,
		      // Writeback info
		      Bool wb_valid, RW_from_Retire wb) if (initialized);
      actionvalue
	 let t3 <- fav_gpr_access (flog, has_rs1, rs1, has_rs2, rs2, has_rd, rd, wb_valid, wb);
	 return t3;
      endactionvalue
   endmethod

   // For debugger                                                       // \belide{3}
   method Bit #(xlen) read_dm  (Bit #(5) rs);
      return ((rs == 0) ? 0 : rf.sub (rs));
   endmethod

   method Action      write_dm (Bit #(5) rd, Bit #(xlen) rd_val);        // \eelide
      rf.upd (rd, rd_val);
   endmethod
endmodule                                                           // \elatex{mkGPRs}

// ****************************************************************
// A monomorphic version synthesized into Verilog

(* synthesize *)                                         // \blatex{mkGPRs_synth}
module mkGPRs_synth (GPRs_IFC #(XLEN));
   let ifc <- mkGPRs;
   return ifc;
endmodule                                                // \elatex{mkGPRs_synth}

// ****************************************************************

endpackage
