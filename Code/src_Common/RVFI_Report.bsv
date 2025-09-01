// Copyright (c) 2025 Rishiyur S. Nikhil.  All Rights Reserved.

package RVFI_Report;

// ****************************************************************
// The 'mkRVFI_Report' module assembles information on committed
// instructions into an 'RVFI' struct. These structs are streamed out
// to a verifier, and/or to be logged.

// The RVFI fields (RISC-V Formal Interface) were originally defined
// by Claire Wolf:
//     http://www.clifford.at/papers/2017/riscv-formal/slides.pdf
// U.Cambridge's 'TestRIG' tool defines a BSV struct for this,
// ('RVFI_DII_Execution') which we use here.

// ****************************************************************
// Imports from libraries

import FIFOF :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;

// ----------------
// Local imports

import Arch           :: *;
import Instr_Bits     :: *;
import Inter_Stage    :: *;
import Mem_Req_Rsp    :: *;
import RVFI_DII_Types :: *;    // For 'RVFI_DII_Execution' struct

// ****************************************************************
// INTERFACE

interface RVFI_Report_IFC;
   method Action rvfi_Int (RR_to_Retire  x,
			   EX_to_Retire  x2,
			   Bit #(64)     inum,
			   Epoch epoch);

   method Action rvfi_Control (RR_to_Retire          x,
			       EX_Control_to_Retire  x2,
			       Bit #(64)             inum,
			       Epoch                 epoch);

   method Action rvfi_DMem (RR_to_Retire  x,
			    Mem_Rsp       x2,
			    Bit #(32)     rd_val,
			    Bit #(64)     inum,
			    Epoch         epoch);

   method Action rvfi_CSRRxx (RR_to_Retire  x,
			      Bit #(XLEN)   rd_val,
			      Bit #(64)     inum,
			      Epoch         epoch);

   method Action rvfi_MRET (RR_to_Retire  x,
			    Bit #(XLEN)   pc_wdata,
			    Bit #(64)     inum,
			    Epoch         epoch);

   method Action rvfi_Exception (RR_to_Retire  x,
				 Bit #(XLEN)   tvec,
				 Bit #(64)     inum,
				 Epoch         epoch);

   // ----------------------------------------------------------------
   // Output stream of RVFI reports (to verifier/logger)
   interface FIFOF_O #(RVFI_DII_Execution #(XLEN, 64)) fo_rvfi_reports;
endinterface

// ****************************************************************
// Note: In RVFI_DII_Execution.pc_wdata, we use the lower-order bits
// for the epoch.

// ****************************************************************
// Default RVFI value; each method in the module overrides some fields

RVFI_DII_Execution #(XLEN, 64) rvfi_default =
RVFI_DII_Execution {
   // Bit#(64)  Instr number: INSTRET value after completion.
   rvfi_order: 0,
   // Bool      Trap indicator: Invalid decode, misaligned access or
   //           jump command to misaligned address.
   rvfi_trap: False,
   // Bool      Halt indicator: Marks last instr retired
   rvfi_halt: False,
   // Bool      Trap handler: Set for first instr in trap handler.
   rvfi_intr: False,

   // Bit#(32)  Instr word: 32-bit command value.
   rvfi_insn: 0,

   // Bit#(5)   Read register addresses: Can be arbitrary when not used,
   //           otherwise set as decoded.
   rvfi_rs1_addr: 0,
   rvfi_rs2_addr: 0,

   // Bit#(xlen)    Read register values: Values as read from registers named
   //               above. Must be 0 if register ID is 0.
   rvfi_rs1_data: 0,
   rvfi_rs2_data: 0,

   // Bit#(xlen)    PC before instr: PC for current instruction
   rvfi_pc_rdata: 0,
   // Bit#(xlen)    PC after instr: either PC + 4 or jump target.
   rvfi_pc_wdata: 0,

   // Bit#(memwidth)    Write data: Data written to memory by this command.
   //                   If SC fails then value is not written; indicate as wmask = 0.
   rvfi_mem_wdata: 0,

   // Bit#(5)       Write register address:  MUST be 0 if not used.
   rvfi_rd_addr: 0,
   // Bit#(xlen)    Write register value:    MUST be 0 if rd_addr is 0.
   rvfi_rd_wdata: 0,

   // Bit#(xlen)    Memory access addr: Points to byte address
   rvfi_mem_addr: 0,

   // Bit#(TDiv#(memwidth,8))    Read mask: Indicates valid bytes read. 0 if unused.
   rvfi_mem_rmask: 0,
   // Bit#(TDiv#(memwidth,8))    Write mask: Indicates valid bytes written. 0 if unused.
   rvfi_mem_wmask: 0,
   // Bit#(xlen)    Read data: Data read from mem_addr (i.e. before write)
   rvfi_mem_rdata: 0
   };

// ****************************************************************
// IMPLEMENTATION MODULE

(* synthesize *)
module mkRVFI_Report (RVFI_Report_IFC);
   FIFOF #(RVFI_DII_Execution #(XLEN, 64)) f_reports <- mkFIFOF;

   // ================================================================
   // BEHAVIOR

   // ================================================================
   // INTERFACE

   // ----------------------------------------------------------------

   method Action rvfi_Int (RR_to_Retire  x,
			   EX_to_Retire  x2,
			   Bit #(64)     inum,
			   Epoch         epoch);
      action
	 let r = rvfi_default;
	 r.rvfi_order    = inum;
	 r.rvfi_insn     = x.instr;
	 r.rvfi_rs1_addr = instr_rs1 (x.instr);
	 r.rvfi_rs2_addr = instr_rs2 (x.instr);
	 r.rvfi_rs1_data = x.rs1_val;
	 r.rvfi_rs2_data = x.xtra.rs2_val;
	 if (x.has_rd) begin
	    r.rvfi_rd_addr  = instr_rd (x.instr);
	    r.rvfi_rd_wdata = ((instr_rd (x.instr) == 0) ? 0 : x2.data);
	 end
	 r.rvfi_pc_rdata = x.pc;
	 r.rvfi_pc_wdata = (x.fallthru_pc | zeroExtend (epoch));

	 f_reports.enq (r);
      endaction
   endmethod

   // ----------------------------------------------------------------

   method Action rvfi_Control (RR_to_Retire          x,
			       EX_Control_to_Retire  x2,
			       Bit #(64)             inum,
			       Epoch                 epoch);
      action
	 let r = rvfi_default;
	 r.rvfi_order    = inum;
	 r.rvfi_insn     = x.instr;
	 r.rvfi_rs1_addr = instr_rs1 (x.instr);
	 r.rvfi_rs2_addr = instr_rs2 (x.instr);
	 r.rvfi_rs1_data = x.rs1_val;
	 r.rvfi_rs2_data = x.xtra.rs2_val;
	 r.rvfi_pc_rdata = x.pc;
	 r.rvfi_pc_wdata = (x2.next_pc | zeroExtend (epoch));
	 if (x.has_rd) begin
	    r.rvfi_rd_addr  = instr_rd (x.instr);
	    r.rvfi_rd_wdata = ((instr_rd (x.instr) == 0) ? 0 : x2.data);
	 end
	 f_reports.enq (r);
      endaction
   endmethod

   // ----------------------------------------------------------------

   method Action rvfi_DMem (RR_to_Retire  x,
			    Mem_Rsp       x2,
			    Bit #(32)     rd_val,
			    Bit #(64)     inum,
			    Epoch         epoch);
      action
	 let r = rvfi_default;
	 r.rvfi_order    = inum;
	 r.rvfi_insn     = x.instr;

	 Bit #(8) mask = case (x.instr [13:12])
			    2'b00: 8'b_00000001;    // Byte
			    2'b01: 8'b_00000011;    // Halfword
			    2'b10: 8'b_00001111;    // Word
			    2'b11: 8'b_11111111;    // Doubleword
			 endcase;

	 if (x2.req_type == funct5_LOAD) begin
	    r.rvfi_rs1_addr = instr_rs1 (x.instr);
	    r.rvfi_rs1_data = x.rs1_val;
	    r.rvfi_mem_addr  = truncate (x2.addr);
	    r.rvfi_mem_rdata = truncate (x2.data);
	    r.rvfi_mem_rmask = mask;
	    r.rvfi_rd_addr  = instr_rd (x.instr);
	    r.rvfi_rd_wdata = rd_val;
	 end
	 else if (x2.req_type == funct5_STORE) begin
	    r.rvfi_rs1_addr = instr_rs1 (x.instr);
	    r.rvfi_rs1_data = x.rs1_val;
	    r.rvfi_rs2_addr = instr_rs2 (x.instr);
	    r.rvfi_rs2_data = x.xtra.rs2_val;
	    r.rvfi_mem_addr  = truncate (x2.addr);
	    r.rvfi_mem_wdata = zeroExtend (x.xtra.rs2_val);
	    r.rvfi_mem_wmask = mask;
	 end
	 else if ((x2.req_type == funct5_FENCE)
		  || (x2.req_type == funct5_FENCE_I))
	    begin
	       noAction;
	    end
	 else begin
	    // impossible
	 end

	 r.rvfi_pc_rdata = x.pc;
	 r.rvfi_pc_wdata = (x.fallthru_pc | zeroExtend (epoch));

	 f_reports.enq (r);
      endaction
   endmethod

   // ----------------------------------------------------------------

   method Action rvfi_CSRRxx (RR_to_Retire  x,
			      Bit #(XLEN)   rd_val,
			      Bit #(64)     inum,
			      Epoch         epoch);
      action
	 let r = rvfi_default;
	 r.rvfi_order    = inum;
	 r.rvfi_insn     = x.instr;
	 r.rvfi_rs1_addr = instr_rs1 (x.instr);
	 r.rvfi_rs1_data = x.rs1_val;
	 if (x.has_rd) begin
	    r.rvfi_rd_addr  = instr_rd (x.instr);
	    r.rvfi_rd_wdata = ((instr_rd (x.instr) == 0) ? 0 : rd_val);
	 end
	 r.rvfi_pc_rdata = x.pc;
	 r.rvfi_pc_wdata = (x.fallthru_pc | zeroExtend (epoch));

	 f_reports.enq (r);
      endaction
   endmethod

   // ----------------------------------------------------------------

   method Action rvfi_MRET (RR_to_Retire  x,
			    Bit #(XLEN)   pc_wdata,
			    Bit #(64)     inum,
			    Epoch         epoch);
      action
	 let r = rvfi_default;
	 r.rvfi_order    = inum;
	 r.rvfi_insn     = x.instr;
	 r.rvfi_pc_rdata = x.pc;
	 r.rvfi_pc_wdata = (pc_wdata | zeroExtend (epoch));

	 f_reports.enq (r);
      endaction
   endmethod

   // ----------------------------------------------------------------

   method Action rvfi_Exception (RR_to_Retire  x,
				 Bit #(XLEN)   tvec,
				 Bit #(64)     inum,
				 Epoch         epoch);
      action
	 let r = rvfi_default;
	 r.rvfi_order    = inum;
	 r.rvfi_trap     = True;
	 r.rvfi_insn     = x.instr;
	 r.rvfi_rs1_addr = 0;    // instr_rs1 (x.instr);
	 r.rvfi_rs2_addr = 0;    // instr_rs2 (x.instr);
	 r.rvfi_rs1_data = 0;    // x.rs1_val;
	 r.rvfi_rs2_data = 0;    // x.rs2_val;
	 if (x.has_rd)
	    r.rvfi_rd_addr  = instr_rd (x.instr);
	 r.rvfi_pc_rdata = x.pc;
	 r.rvfi_pc_wdata = (tvec | zeroExtend (epoch));

	 f_reports.enq (r);
      endaction
   endmethod

   // ================================================================
   // Output stream of RVFI reports (to verifier/logger)
   interface fo_rvfi_reports = to_FIFOF_O (f_reports);
endmodule

// ****************************************************************

endpackage
