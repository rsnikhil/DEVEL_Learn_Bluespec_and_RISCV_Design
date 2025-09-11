// Copyright (c) 2025 Rishiyur S. Nikhil.  All Rights Reserved.

package CPU_and_Mem;

// ****************************************************************
// This package implements a resettable CPU+Mem for TestRIG

// ****************************************************************
// Imports from libraries

import FIFOF        :: *;
import Connectable  :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;
import GetPut_Aux :: *;
import RVFI_DII   :: *;

// ----------------
// Local imports

import Utils       :: *;
import Arch        :: *;
import Mem_Req_Rsp :: *;
import CPU_IFC     :: *;
import CPU         :: *;
import Inter_Stage :: *;

import Mems_Devices :: *;

import TestRIG_Instr_Queue :: *;

// ****************************************************************

Integer verbosity = 0;

// ****************************************************************

function Fmt fshow2_RVFI_DII_Execution (RVFI_DII_Execution #(a, b) x);
   Fmt acc = $format("[%0d] PC:%08h I:%08h PC':%08h",
		     x.rvfi_order,
		     x.rvfi_pc_rdata,
		     x.rvfi_insn,
		     x.rvfi_pc_wdata);
   if (x.rvfi_trap) acc = acc + $format (" TRAP");
   acc = acc + $format(" Rd:%02d", x.rvfi_rd_addr);
   if (x.rvfi_rd_addr != 0) acc = acc + $format(" RdW:%08h", x.rvfi_rd_wdata);
   if (x.rvfi_mem_wmask != 0) begin
      acc = acc + $format(" MA:%08h MWD:%08h", x.rvfi_mem_addr, x.rvfi_mem_wdata);
      acc = acc + $format(" MWM:0b%04b", x.rvfi_mem_wmask);
   end
   if (x.rvfi_mem_rmask != 0) begin
      acc = acc + $format(" MA:%08h", x.rvfi_mem_addr);
      acc = acc + $format(" MRM:0b%04b", x.rvfi_mem_rmask);
   end
   return acc;
endfunction

// ****************************************************************
// INTERFACE

interface CPU_and_Mem_IFC;
   // Input stream of instructions from TestRIG
   method  Dii_Id mv_next_dii_id;
   method  Action ma_feed_instr (Bit #(32) instr);

   // Output stream of RVFI reports to TestRIG
   interface FIFOF_O #(RVFI_DII_Execution #(XLEN, 64)) fo_rvfi_reports;
endinterface

// ****************************************************************
// MODULE

(* synthesize *)
module mkCPU_and_Mem (CPU_and_Mem_IFC);
   Reg #(File) rg_logfile <- mkReg (InvalidFile);

   // Instantiate the CPU
   CPU_IFC cpu <- mkCPU;

   // Instantiate the memory model
   Mems_Devices_IFC mems_devices <- mkMems_Devices (dummy_FIFOF_O,    // IMem_reqs
						    dummy_FIFOF_I,    // IMem_rsps
						    cpu.fo_DMem_S_req,
						    cpu.fi_DMem_S_rsp,
						    cpu.fo_DMem_S_commit,
						    cpu.fo_DMem_req,
						    cpu.fi_DMem_rsp,
						    cpu.fo_dbg_to_mem_req,
						    cpu.fi_dbg_from_mem_rsp);

   // Tie off debug module's memory interfaces
   FIFOF_O #(Dbg_to_CPU_Pkt) d1 = dummy_FIFOF_O;
   mkConnection (cpu.fi_dbg_to_CPU_pkt, d1);

   FIFOF_I #(Dbg_from_CPU_Pkt) d2 = dummy_FIFOF_I;
   mkConnection (d2, cpu.fo_dbg_from_CPU_pkt);

   Reg #(int) rg_top_step <- mkReg (0);    // Sequences startup steps

   // ----------------
   // RVFI plumbing

   // For instructions incoming from TestRIG
   Reg #(Dii_Id)            rg_dii_id <- mkReg (0);
   TestRIG_Instr_Queue_IFC  instr_queue <- mkTestRIG_Instr_Queue;

   // For reports outgoing to TestRIG
   FIFOF #(RVFI_DII_Execution #(XLEN, 64)) f_rvfi_reports <- mkFIFOF;

   Reg #(Epoch) rg_epoch <- mkReg (0);

   // ****************************************************************
   // BEHAVIOR

   // ================================================================
   // Startup sequence

   // Show banner and open logfile
   rule rl_step0 (rg_top_step == 0);
      $display ("================================================================");
      $display ("TestRIG Drum/Fife simulation top-level.  Command-line options:");
      $display ("  +log      Generate log (trace) file (can become large!)");

      let log <- $test$plusargs ("log");
      File f = InvalidFile;
      if (log) begin
	 $display ("INFO: Logfile is: log.txt");
	 f <- $fopen ("log.txt", "w");
      end
      else
	 $display ("INFO: No logfile");
      rg_logfile  <= f;


      rg_top_step <= 1;
   endrule

   // Initialize modules
   rule rl_step1 (rg_top_step == 1);
      let with_debugger <- $test$plusargs ("debug");

      Bit #(64) addr_base_mem = fromInteger (valueOf (RVFI_DII_Mem_Start));
      Bit #(64) size_B_mem    = fromInteger (valueOf (RVFI_DII_Mem_Size));


      let init_params = Initial_Params {flog:              rg_logfile,
					pc_reset_value:    truncate (addr_base_mem),
					addr_base_mem:     addr_base_mem,
					size_B_mem:        size_B_mem,
					dbg_listen_socket: (with_debugger ? 30000 : 0)};
      cpu.init (init_params);
      mems_devices.init (init_params);

      rg_top_step <= 2;
   endrule

   // Get ready to run
   rule rl_step2 (rg_top_step == 2);
      $display ("================================================================");
      rg_top_step <= 3;
   endrule

   // ... system running

   Integer cycle_limit = 0;    // Use 0 for no-limit

   rule rg_step3 (rg_top_step == 3);
      // Quit if reached cycle-limit
      let x <- cur_cycle;
      if ((cycle_limit > 0) && (x > fromInteger (cycle_limit))) begin
	 $display ("================================================================");
         $display ("Quit (reached cycle_limit %0d)", cycle_limit);
	 rg_top_step <= 4;
      end
   endrule

   rule rl_step4 (rg_top_step == 4);
      $finish (0);
   endrule

   // ================================================================
   // Relay instructions from TestRIG's VEngine into CPU's IMem response port

   Reg #(Bit #(64)) rg_last_arch_inum <- mkReg ('1);

   rule rl_relay_instrs_from_TestRIG;
      let req = cpu.fo_IMem_req.first;
      Bit #(64) arch_inum = req.data;
      if (verbosity != 0) begin
	 $display ("deq (in Top_TestRIG.CPU_and_Mem.rl_relay_instrs)");
	 $display ("    arch_inum last %0d now %0d", rg_last_arch_inum, arch_inum);
	 $display ("    epoch last %0d now %0d", rg_epoch, req.epoch);
	 match { .tl, .qsize } = instr_queue.mv_q_tl_size;
	 $display ("    tl %0d  qsize = %0d", tl, qsize);
      end

      let m_instr <- instr_queue.try_deq (arch_inum);
      if (m_instr matches tagged Valid .instr) begin
	 cpu.fo_IMem_req.deq;
	 let rsp = Mem_Rsp {rsp_type: MEM_RSP_OK,
			    data:     zeroExtend (instr),
			    req_type: req.req_type,
			    size:     req.size,
			    addr:     req.addr,
			    xtra: Mem_Rsp_Xtra {
			       inum:  req.xtra.inum,
			       pc:    req.xtra.pc,
			       instr: instr}
			    };
	 cpu.fi_IMem_rsp.enq (rsp);

	 rg_last_arch_inum <= arch_inum;

	 if (verbosity != 0)
	    $display ("    instr %08h", instr);
      end
      else if (req.epoch != rg_epoch) begin
	 cpu.fo_IMem_req.deq;
	 Bit #(32) instr = 0;    // bogus instr; will be discarded anyway
	 let rsp = Mem_Rsp {rsp_type: MEM_RSP_OK,
			    data:     zeroExtend (instr),
			    req_type: req.req_type,
			    size:     req.size,
			    addr:     req.addr,
			    xtra: Mem_Rsp_Xtra {
			       inum:  req.xtra.inum,
			       pc:    req.xtra.pc,
			       instr: instr}
			    };
	 cpu.fi_IMem_rsp.enq (rsp);

	 rg_last_arch_inum <= arch_inum;

	 if (verbosity != 0)
	    $display ("    BOGUS instr");
      end
      else begin
	 if (verbosity != 0)
	    $display ("    NO instr");
      end
   endrule

   // This rule is unnecessary; could plumb cpu.fo_rvfi_reports to interface directly.
   // This rule allows printing reports for debugging.
   rule rl_relay_rvfi_reports_to_TestRIG;
      let rpt <- pop_o (cpu.fo_rvfi_reports);
      rg_epoch <= truncate (rpt.rvfi_pc_wdata);
      Epoch epoch_mask = '1;
      rpt.rvfi_pc_wdata = rpt.rvfi_pc_wdata & (~ zeroExtend (epoch_mask));
      f_rvfi_reports.enq (rpt);
      if (verbosity != 0) begin
	 $display ("rl_relay_rvfi_reports: to TestRIG (in Top_TestRIG.CPU_and_Mem)");
	 $display ("    ", fshow2_RVFI_DII_Execution (rpt));
      end
   endrule

   // ================================================================
   // Relay MTIME to CPU's CSRs module

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_relay_MTIME;
      let t <- mems_devices.rd_MTIME;
      cpu.set_TIME (t);
   endrule

   // ================================================================
   // Relay MTIP to CPU's CSRs module

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_relay_MTIP;
      let t = mems_devices.mv_MTIP;
      cpu.set_MIP_MTIP (t);
   endrule

   // ================================================================
   // INTERFACE

   // Instruction stream from (bridge to) TestRIG Verification Engine
   method Dii_Id mv_next_dii_id;
      return rg_dii_id;
   endmethod

   method  Action ma_feed_instr (Bit #(32) instr);
      instr_queue.enq (instr);
      rg_dii_id <= rg_dii_id + 1;
      if (verbosity != 0) begin
	 $display ("enq (in CPU_and_Mem.ma_feed_instr)");
	 match { .tl, .qsize } = instr_queue.mv_q_tl_size;
	 $display ("    tl %0d  qsize = %0d", tl, qsize);
	 $display ("    dii_id %0d  instr %0h", rg_dii_id, instr);
      end
   endmethod

   // ----------------------------------------------------------------
   // Output stream of RVFI reports (to verifier/logger)
   interface fo_rvfi_reports = to_FIFOF_O (f_rvfi_reports);
endmodule

// ****************************************************************

endpackage
