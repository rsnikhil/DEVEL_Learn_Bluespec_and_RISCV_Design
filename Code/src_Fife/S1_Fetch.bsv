// Copyright (c) 2023-2025 Rishiyur S. Nikhil.  All Rights Reserved.

package S1_Fetch;

// ****************************************************************
// Fetch stage, including next-PC predictor

// ****************************************************************
// Imports from bsc libraries

import FIFOF        :: *;
import SpecialFIFOs :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;

// ----------------
// Local imports

import Utils       :: *;
import Arch        :: *;
import Instr_Bits  :: *;
import Mem_Req_Rsp :: *;
import Inter_Stage :: *;

import Fn_Fetch       :: *;

// ****************************************************************
                                                                // \blatex{Fife_Fetch_IFC}
interface Fetch_IFC;
   method Action init (Initial_Params initial_params);

   // Forward out
   interface FIFOF_O #(Fetch_to_Decode)  fo_Fetch_to_Decode;
   interface FIFOF_O #(Mem_Req)          fo_Fetch_to_IMem;

   // Backward in
   interface FIFOF_I #(Fetch_from_Retire) fi_Fetch_from_Retire;
endinterface
                                                                // \elatex{Fife_Fetch_IFC}
// ****************************************************************
// Debugger control

typedef enum { S1_RUNNING, S1_HALTED } S1_RunState
deriving (Bits, Eq, FShow);

Integer verbosity = 0;

// ****************************************************************
                                                                // \blatex{Fife_mkFetch}
(* synthesize *)
module mkFetch (Fetch_IFC);
   // ----------------------------------------------------------------
   // STATE
   Reg #(File) rg_flog    <- mkReg (InvalidFile);    // Debugging           // \belide{3}
                                                                            // \eelide
   Reg #(S1_RunState) rg_runstate <- mkReg (S1_HALTED);

   // Forward out
   FIFOF #(Fetch_to_Decode) f_Fetch_to_Decode <- mkBypassFIFOF;
   FIFOF #(Mem_Req)         f_Fetch_to_IMem   <- mkBypassFIFOF;

   // Backward in
   FIFOF #(Fetch_from_Retire) f_Fetch_from_Retire <- mkPipelineFIFOF;

   // PC and epoch registers
   Reg #(Bit #(XLEN))     rg_pc        <- mkReg (0);
   Reg #(Bit #(W_Epoch))  rg_epoch     <- mkReg (0);
   // instr seq number = fetch number (including speculative fetches)       // \belide{3}
   Reg #(Bit #(64))       rg_inum      <- mkReg (0);
   // architectural instr seq number (excluding speculative fetches)
   Reg #(Bit #(64))       rg_arch_inum <- mkReg (0);

   // One-instr-at-a-time (unpipelined) control
   Reg #(Bool) rg_oiaat       <- mkReg (False);
   Reg #(Bool) rg_oiaat_fetch <- mkReg (True);
                                                                            // \eelide
   // ----------------------------------------------------------------
   // BEHAVIOR

   // Forward flow
   rule rl_Fetch_req ((rg_runstate == S1_RUNNING)
		      && (! f_Fetch_from_Retire.notEmpty)
		      && rg_oiaat_fetch);                                   // \belide{22}
                                                                            // \eelide
      // Predict next PC
      let pred_pc = rg_pc + 4;
      let y <- fn_Fetch (rg_pc, pred_pc, rg_epoch, rg_inum, rg_arch_inum, rg_flog);
      f_Fetch_to_Decode.enq (y.to_D);
      f_Fetch_to_IMem.enq (y.mem_req);

      rg_pc        <= pred_pc;
      rg_inum      <= rg_inum + 1;                                          // \belide{6}
      rg_arch_inum <= rg_arch_inum + 1;

      // If one-instr-at-a-time, disable fetching
      // (will be re-enabled by rl_Fetch_from_Retire)
      if (rg_oiaat) rg_oiaat_fetch <= False;

      log_Fetch (rg_flog, y.to_D, y.mem_req);                               // \eelide
   endrule

   // Backward flow: redirection from Retire
   rule rl_Fetch_from_Retire ((! rg_oiaat) || (! rg_oiaat_fetch));
      let x <- pop_o (to_FIFOF_O (f_Fetch_from_Retire));
      rg_pc        <= x.next_pc;
      rg_epoch     <= x.next_epoch;
      let arch_rollback = rg_inum - x.xtra.inum - 1;                        // \belide{6}
      let new_arch_inum = rg_arch_inum - arch_rollback;
      rg_arch_inum <= new_arch_inum;

      // Debugger support
      if (x.haltreq) begin
	 Fetch_to_Decode to_D = unpack (0);
	 to_D.epoch         = rg_epoch;    // old epoch
	 to_D.halt_sentinel = True;
	 f_Fetch_to_Decode.enq (to_D);
	 rg_runstate <= S1_HALTED;
	 if (verbosity != 0)
	    $display ("S1_Fetch: halt requested; sending halt_sentinel to S2_Decode");
      end
      else if (rg_runstate == S1_HALTED) begin
	 rg_runstate <= S1_RUNNING;
	 if (verbosity != 0)
	    $display ("S1_Fetch: resuming at PC %0h epoch %0d", x.next_pc, x.next_epoch);
      end

      // If one-instr-at-a-time, re-enable fetching
      rg_oiaat_fetch <= True;

      log_Redirect (rg_flog, x);                                            // \eelide
   endrule

   // ----------------------------------------------------------------
   // INTERFACE

   method Action init (Initial_Params initial_params) if (rg_runstate == S1_HALTED);
      rg_pc       <= initial_params.pc_reset_value;
      rg_runstate <= S1_RUNNING;
                                                                            // \belide{6}
      rg_flog    <= initial_params.flog;                                    // \eelide
   endmethod

   // Forward out
   interface fo_Fetch_to_Decode = to_FIFOF_O (f_Fetch_to_Decode);
   interface fo_Fetch_to_IMem   = to_FIFOF_O (f_Fetch_to_IMem);

   // Backward in
   interface fi_Fetch_from_Retire = to_FIFOF_I (f_Fetch_from_Retire);
endmodule
                                                                // \elatex{Fife_mkFetch}
// ****************************************************************

endpackage
