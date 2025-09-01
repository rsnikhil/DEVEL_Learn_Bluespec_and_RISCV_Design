// Copyright (c) 2023-2025 Rishiyur S. Nikhil.  All Rights Reserved.

package S3_RR_WB_b;

// ****************************************************************
// Register-read-and-dispatch, and Register-Write
// * Has scoreboard to keep track of which register are "busy"
// * Stalls if rs1, rs2 or rd are busy
// * Reads input register values

// ****************************************************************
// Imports from bsc libraries

import FIFOF        :: *;
import SpecialFIFOs :: *;    // For mkPipelineFIFOF and mkBypassFIFOF
import Vector       :: *;
import Connectable  :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;
import GetPut_Aux :: *;

// ----------------
// Local imports

import Utils       :: *;
import Arch        :: *;
import Instr_Bits  :: *;
import Mem_Req_Rsp :: *;
import Inter_Stage :: *;
import GPRs_b      :: *;

import Fn_Dispatch :: *;

// ****************************************************************
                                                                // \blatex{Fife_RR_RW_IFC}
interface RR_RW_IFC;
   method Action init (Initial_Params initial_params);

   // Forward in
   interface FIFOF_I #(Decode_to_RR)  fi_Decode_to_RR;

   // Forward out
   interface FIFOF_O #(RR_to_Retire)      fo_RR_to_Retire;
   interface FIFOF_O #(RR_to_EX_Control)  fo_RR_to_EX_Control;
   interface FIFOF_O #(RR_to_EX)          fo_RR_to_EX_Int;
   interface FIFOF_O #(Mem_Req)           fo_DMem_S_req;

   // Backward in
   interface FIFOF_I #(RW_from_Retire)  fi_RW_from_Retire;

   // For debugger
   method Action      gpr_write (Bit #(5) rd, Bit #(XLEN) v);
   method Bit #(XLEN) gpr_read  (Bit #(5) rs);
endinterface
                                                                // \elatex{Fife_RR_RW_IFC}
// ****************************************************************

Integer verbosity = 0;
                                                                // \blatex{Fife_mkRR_RW1}
(* synthesize *)
module mkRR_RW (RR_RW_IFC);
   Reg #(File) rg_flog <- mkReg (InvalidFile);    // debugging        // \belide{3}
                                                                      // \eelide
   // Forward in
   FIFOF #(Decode_to_RR) f_Decode_to_RR <- mkPipelineFIFOF;

   // Forward out
   FIFOF #(RR_to_Retire)     f_RR_to_Retire     <- mkBypassFIFOF;  // Direct
   FIFOF #(RR_to_EX_Control) f_RR_to_EX_Control <- mkBypassFIFOF;
   FIFOF #(RR_to_EX)         f_RR_to_EX_Int     <- mkBypassFIFOF;
   FIFOF #(Mem_Req)          f_DMem_S_req       <- mkBypassFIFOF;

   // Backward in
   FIFOF #(RW_from_Retire) f_RW_from_Retire <- mkPipelineFIFOF;

   // General-Purpose Registers (GPRs)
   GPRs_IFC #(XLEN)  gprs <- mkGPRs_synth;
                                                                // \elatex{Fife_mkRR_RW1}
   Reg #(Bit #(16)) rg_stall_count <- mkReg (0);
                                                                // \blatex{Fife_mkRR_RW2}
   // ================================================================
   // BEHAVIOR: Forward: (reg read, reserve scoreboard) from S2 Decode
   // BEHAVIOR: Backward: (unreserve scoreboard, reg write) from S5 Retire

   rule rl_WB;
      Bool wb_valid = True;
      RW_from_Retire wb <- pop (f_RW_from_Retire);

      // Perform GPR transaction for backward path
      Bool has_rs1 = False; Bit #(5) rs1     = ?;
      Bool has_rs2 = False; Bit #(5) rs2     = ?;
      Bool has_rd  = False; Bit #(5) rd      = ?;
      match { .stall, .rs1_val, .rs2_val }
      <- gprs.gpr_access (rg_flog, has_rs1, rs1, has_rs2, rs2, has_rd,  rd, wb_valid, wb);

      if (stall) begin
	 // No action
	 rg_stall_count <= rg_stall_count + 1;
      end
      else
	 rg_stall_count <= 0;
   endrule

   // This rule fires when there is
   //    a token is available from S2 Decode and it is not halt-sentinel
   // or a token is available from S5 Retire
   (* descending_urgency = "rl_RR_WB, rl_WB" *)
   rule rl_RR_WB (! f_Decode_to_RR.first.halt_sentinel);
      if (rg_stall_count == 'hFFFF) begin                                  // \belide{6}
	 wr_log2 (rg_flog, $format ("CPU.S3.rl_RR_RW: reached %0d stalls; quitting",
				    rg_stall_count));
	 $finish (1);
      end
                                                                           // \eelide
      // Get info from Decode_to_RR packet (forward path), if there is one
      Decode_to_RR x = ?;
      let instr_valid = True;    // TODO: DELETE? f_Decode_to_RR.notEmpty;
      let has_rs1 = False;
      let has_rs2 = False;
      let has_rd  = False;
      if (instr_valid) begin
	 x = f_Decode_to_RR.first;
	 has_rs1 = x.has_rs1;
	 has_rs2 = x.has_rs2;
	 has_rd  = x.has_rd;
      end
      let instr   = x.instr;
      let opclass = x.opclass;
      let rs1     = instr_rs1 (instr);
      let rs2     = instr_rs2 (instr);
      let rd      = instr_rd  (instr);
	    
      // Get info from RW_to_RR packet (backward path), if there is one
      let wb_valid = f_RW_from_Retire.notEmpty;
      RW_from_Retire wb = ?;
      if (wb_valid) begin
	 wb = f_RW_from_Retire.first;
	 f_RW_from_Retire.deq;
      end

      // Perform GPR transaction for both forward and backward path
      // including bypassing of updated rd_val (from wd) into rs1_val and/or rs2_val
      match { .stall, .rs1_val, .rs2_val }
      <- gprs.gpr_access (rg_flog, has_rs1, rs1, has_rs2, rs2, has_rd,  rd, wb_valid, wb);

      if (stall) begin
	 // No action
	 rg_stall_count <= rg_stall_count + 1;                                   // \belide{9}

	 if (instr_valid) begin
	    wr_log (rg_flog, $format ("CPU.rl_RR.hazard_stall:"));
	    wr_log_cont (rg_flog, $format ("    ", fshow_Decode_to_RR (x)));
	    ftrace (rg_flog, x.xtra.inum, x.pc, x.instr, "RR.S", $format (""));  // \eelide
	 end
      end
      else begin
	 rg_stall_count <= 0;                                              // \belide{9}
                                                                           // \eelide
	 f_Decode_to_RR.deq;

	 // Dispatch to one of the next-stage pipes
	 Result_Dispatch z <- fn_Dispatch (x, rs1_val, rs2_val, rg_flog);

	 // Direct to Retire
	 f_RR_to_Retire.enq (z.to_Retire);

	 // Dispatch
	 case (z.to_Retire.exec_tag)
	    EXEC_TAG_DIRECT:  noAction;
	    EXEC_TAG_CONTROL: f_RR_to_EX_Control.enq (z.to_EX_Control);
	    EXEC_TAG_INT:     f_RR_to_EX_Int.enq (z.to_EX);
	    EXEC_TAG_DMEM:    f_DMem_S_req.enq (z.to_EX_DMem);
	 endcase

         // ---------------- DEBUG                                      // \belide{9}
	 case (z.to_Retire.exec_tag)
	    EXEC_TAG_DIRECT:  log_Dispatch_Direct (rg_flog, z.to_Retire);
	    EXEC_TAG_CONTROL: log_Dispatch_Control (rg_flog, z.to_Retire, z.to_EX_Control);
	    EXEC_TAG_INT:     log_Dispatch_Int (rg_flog, z.to_Retire, z.to_EX);
	    EXEC_TAG_DMEM:    log_Dispatch_DMem (rg_flog, z.to_Retire, z.to_EX, z.to_EX_DMem);
	    default: begin
			wr_log (rg_flog, $format ("CPU.Dispatch:"));
			wr_log_cont (rg_flog,
				     $format ("    ", fshow_RR_to_Retire (z.to_Retire)));
			wr_log_cont (rg_flog, $format ("    -> IMPOSSIBLE"));
			// IMPOSSIBLE
			$finish (1);
		     end
	 endcase                                                        // \eelide
      end
   endrule                                                      // \elatex{Fife_mkRR_RW2}

   rule rl_RR_Dispatch_halting (f_Decode_to_RR.first.halt_sentinel);
      f_Decode_to_RR.deq;
      RR_to_Retire y  = unpack (0);
      y.exec_tag      = EXEC_TAG_DIRECT;
      y.epoch         = f_Decode_to_RR.first.epoch;
      y.halt_sentinel = True;
      f_RR_to_Retire.enq (y);

      if (verbosity != 0)
	 $display ("S3_RR_RW_Dispatch: halt requested; sending halt_sentinel to S5_Retire");
   endrule
                                                                // \blatex{Fife_mkRR_RW4}
   // ================================================================
   // INTERFACE

   method Action init (Initial_Params initial_params);
      $display ("GPRs: bypassed");
      rg_flog <= initial_params.flog;
   endmethod

   // Forward in
   interface fi_Decode_to_RR = to_FIFOF_I (f_Decode_to_RR);

   // Forward out
   interface fo_RR_to_Retire     = to_FIFOF_O (f_RR_to_Retire);
   interface fo_RR_to_EX_Control = to_FIFOF_O (f_RR_to_EX_Control);
   interface fo_RR_to_EX_Int     = to_FIFOF_O (f_RR_to_EX_Int);
   interface fo_DMem_S_req       = to_FIFOF_O (f_DMem_S_req);

   // Backward in
   interface fi_RW_from_Retire = to_FIFOF_I (f_RW_from_Retire);

   // For debugger
   method Action gpr_write (Bit #(5) rd, Bit #(XLEN) v);
      gprs.write_dm (rd, v);
   endmethod

   method Bit #(XLEN) gpr_read (Bit #(5) rs);
      return gprs.read_dm (rs);
   endmethod
endmodule
                                                                // \elatex{Fife_mkRR_RW4}
// ****************************************************************

endpackage
