// Copyright (c) 2025 Rishiyur S. Nikhil. All Rights Reserved.

package Top_TestRIG;

// ****************************************************************
// This is the top-level BSV module for the TestRIG setup for Fife/Drum.

// ****************************************************************
// Imports from libraries

import FIFOF  :: *;
import GetPut :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle :: *;
import Semi_FIFOF :: *;

import RVFI_DII :: *;

// ----------------
// Local imports

import CPU_and_Mem :: *;

// ****************************************************************

(* synthesize *)
module mkTop_TestRIG (Empty);

   Integer default_tcp_port = 30000;

   RVFI_DII_Bridge_Scalar #(32, 64)
   bridge <- mkRVFI_DII_Bridge_Scalar ("Fife/Drum", default_tcp_port);

   CPU_and_Mem_IFC cpu_and_mem <- mkCPU_and_Mem (reset_by bridge.new_rst);

   // Forward instrs from bridge to CPU
   rule rl_forward_instrs;
      let dii_id = cpu_and_mem.mv_next_dii_id;
      let m_instr <- bridge.client.getInst (dii_id);
      if (m_instr matches tagged Valid .instr)
	 cpu_and_mem.ma_feed_instr (instr);
   endrule

   // Forward RVFI packets from CPU to bridge
   rule rl_forward_RVFI;
      let rvfi <- pop_o (cpu_and_mem.fo_rvfi_reports);
      bridge.client.report.put (rvfi);
   endrule

   // ================================================================
   // INTERFACE

   // Empty
endmodule

// ****************************************************************

endpackage
