// Copyright (c) 2023-2024 Rishiyur S. Nikhil.  All Rights Reserved.

package Mems_Devices;

// ****************************************************************
// The "Memory System" for Drum/Fife

// TODO: interrupt requests from UART, other devices
// ****************************************************************
// Imports from libraries

import FIFOF        :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle :: *;
import Semi_FIFOF :: *;

// ----------------
// Local imports

import Utils        :: *;
import Instr_Bits   :: *;    // for funct5_LOAD/STORE/...
import Mem_Req_Rsp  :: *;
import Inter_Stage  :: *;
import Store_Buffer :: *;

// ****************************************************************
// Debugging support

Integer verbosity = 0;
Integer verbosity_CLINT = 0;

// ****************************************************************

interface Mems_Devices_IFC;
   method Action init (Initial_Params initial_params);
   method ActionValue #(Bit #(64)) rd_MTIME;
   method Bit #(1) mv_MTIP;
endinterface

// ****************************************************************

typedef enum {CLIENT_IMEM, CLIENT_DMEM, CLIENT_MMIO} Client_ID
deriving (Bits, Eq, FShow);

module mkMems_Devices #(FIFOF_O #(Mem_Req) fo_IMem_req,
			FIFOF_I #(Mem_Rsp) fi_IMem_rsp,

			FIFOF_O #(Mem_Req) fo_DMem_req,
			FIFOF_I #(Mem_Rsp) fi_DMem_rsp,
			FIFOF_O #(Retire_to_DMem_Commit) fo_DMem_commit,

			FIFOF_O #(Mem_Req) fo_MMIO_req,
			FIFOF_I #(Mem_Rsp) fi_MMIO_rsp,

			// From/to remote debugger
			FIFOF_O #(Mem_Req) fo_Dbg_req,
			FIFOF_I #(Mem_Rsp) fi_Dbg_rsp)
                      (Mems_Devices_IFC);

   // Store buffer for speculative mem ops
   Store_Buffer_IFC #(4) spec_sto_buf <- mkStore_Buffer (fo_DMem_req,
							 fi_DMem_rsp,
							 fo_DMem_commit);

   Reg #(Bool)  rg_running <- mkReg (False);
   Reg #(File)  rg_logfile <- mkReg (InvalidFile);

   // ****************************************************************
   // MTIME and MTIMECMP

   // Bit #(64) addr_base_CLINT = 'h_1000_0000;
   Bit #(64) addr_base_CLINT = 'h_0200_0000;
   Bit #(64) addr_MTIME      = addr_base_CLINT + 'h_BFF8;
   Bit #(64) addr_MTIMECMP   = addr_base_CLINT + 'h_4000;

   Reg #(Bit #(64)) rg_MTIME    <- mkReg (0);
   Reg #(Bit #(64)) rg_MTIMECMP <- mkReg (0);

   function Bool for_MTIME (Mem_Req mr);
      Bool access0 = ((mr.addr == addr_MTIME)
		      && ((mr.size == MEM_4B) || (mr.size == MEM_8B)));
      Bool access4 = ((mr.addr == addr_MTIME + 4)
		      && (mr.size == MEM_4B));
      return (access0 || access4);
   endfunction

   function Bool for_MTIMECMP (Mem_Req mr);
      Bool access0 = ((mr.addr == addr_MTIMECMP)
		      && ((mr.size == MEM_4B) || (mr.size == MEM_8B)));
      Bool access4 = ((mr.addr == addr_MTIMECMP + 4)
		      && (mr.size == MEM_4B));
      return (access0 || access4);
   endfunction

   function ActionValue #(Tuple2 #(Mem_Rsp_Type, Bit #(64)))
            fav_MTIME_MTIMECMP (Mem_Req mem_req, Reg #(Bit #(64)) rg);
      actionvalue

	 Mem_Rsp_Type mem_rsp_type = MEM_RSP_ERR;
	 Bit #(64)    rdata        = rg;
	 Bit #(64)    wdata        = ?;

	 // Loads
	 if (mem_req.req_type == funct5_LOAD) begin
	    mem_rsp_type = MEM_RSP_OK;
	    if (mem_req.addr [2] == 0)  begin
	       if (mem_req.size == MEM_4B)
		  rdata = zeroExtend (rg [31:0]);
	    end
	    else
	       rdata = zeroExtend (rg [63:32]);
	 end

	 // Stores
	 else begin
	    mem_rsp_type = MEM_RSP_OK;

	    if (mem_req.addr [2] == 0)  begin
	       if (mem_req.size == MEM_4B)
		  wdata = { rg [63:32], mem_req.data [31:0] };
	       else
		  wdata = mem_req.data;
	    end
	    else
	       wdata = { mem_req.data [31:0], rg [31:0] };
	    rg   <= wdata;
	    rdata = wdata;

	 end

	 if (verbosity_CLINT != 0) begin
	    $display (fshow_Mem_Req (mem_req));
	    $write ("    => rsp_type: ", fshow (mem_rsp_type));
	    if (mem_req.req_type == funct5_LOAD)
	       $write ("  rdata %0h", rdata);
	    else if (for_MTIMECMP (mem_req) && (wdata >= rg_MTIME))
	       $write ("  ticks to timer IRQ: %0d", wdata - rg_MTIME);
	    $display ("");
	 end

	 return tuple2 (mem_rsp_type, rdata);
      endactionvalue
   endfunction

   // ****************************************************************
   // BEHAVIOR

   // ================================================================

   function Action fa_mem_req_rsp (FIFOF_O #(Mem_Req) fo_mem_req,
				   FIFOF_I #(Mem_Rsp) fi_mem_rsp,
				   Client_ID          client_id,
				   Integer            verbosity);
      action
	 Mem_Rsp_Type mem_rsp_type = ?;
	 Bit #(64)    rdata = ?;

	 let mem_req <- pop_o (fo_mem_req);
	 if (for_MTIME (mem_req)) begin
	    if (verbosity_CLINT != 0) $display ("Accessing MTIME");
	    match { .x, .y } <- fav_MTIME_MTIMECMP (mem_req, rg_MTIME);
	    mem_rsp_type = x;
	    rdata        = y;
	 end
	 else if (for_MTIMECMP (mem_req)) begin
	    if (verbosity_CLINT != 0) $display ("Accessing MTIMECMP");
	    match { .x, .y } <- fav_MTIME_MTIMECMP (mem_req, rg_MTIMECMP);
	    mem_rsp_type = x;
	    rdata        = y;
	 end
	 else begin
	    Bit #(128) wdata   = zeroExtend (mem_req.data);
	    Bit #(96)  result <- c_mems_devices_req_rsp (mem_req.xtra.inum,
							 zeroExtend (pack (mem_req.req_type)),
							 zeroExtend (pack (mem_req.size)),
							 mem_req.addr,
							 zeroExtend (pack (client_id)),
							 wdata);
	    mem_rsp_type = unpack (truncate (result [31:0]));
	    rdata        = result [95:32];
	 end
	 Mem_Rsp mem_rsp = Mem_Rsp {req_type: mem_req.req_type,
				    size:     mem_req.size,
				    addr:     mem_req.addr,
				    rsp_type: mem_rsp_type,
				    data:     rdata,
				    xtra: Mem_Rsp_Xtra {
				       inum:  mem_req.xtra.inum,
				       pc:    mem_req.xtra.pc,
				       instr: mem_req.xtra.instr}
				    };
	 fi_mem_rsp.enq (mem_rsp);

	 if (verbosity != 0) begin
	    wr_log (rg_logfile, $format ("mkMems_Devices: for client ", fshow (client_id)));
	    wr_log_cont (rg_logfile, $format ("    ", fshow_Mem_Req (mem_req)));
	    Bool show_data = (mem_req.req_type != funct5_STORE);
	    wr_log_cont (rg_logfile, $format ("    ", fshow_Mem_Rsp (mem_rsp, show_data)));
	 end
      endaction
   endfunction

   // Fetch mem ops
   rule rl_IMem_req_rsp (rg_running);
      fa_mem_req_rsp (fo_IMem_req, fi_IMem_rsp, CLIENT_IMEM, 0);
   endrule

   // Speculative mem ops
   rule rl_DMem_req_rsp (rg_running);
      Bit #(32) client = 1;
      fa_mem_req_rsp (spec_sto_buf.fo_mem_req, spec_sto_buf.fi_mem_rsp, CLIENT_DMEM, 1);
   endrule

   // Non-speculative mem ops
   rule rl_MMIO_req_rsp (rg_running);
      Bit #(32) client = 2;
      fa_mem_req_rsp (fo_MMIO_req, fi_MMIO_rsp, CLIENT_MMIO, 1);
   endrule

   // Remote debugger mem ops (note: using CLIENT_MMIO)
   rule rl_Dbg_req_rsp (rg_running);
      Bit #(32) client = 2;
      fa_mem_req_rsp (fo_Dbg_req, fi_Dbg_rsp, CLIENT_MMIO, 1);
   endrule

   // ================================================================

   (* descending_urgency =
      "rl_IMem_req_rsp, rl_DMem_req_rsp, rl_MMIO_req_rsp, rl_Dbg_req_rsp, rl_count_MTIME" *)
   rule rl_count_MTIME;
      rg_MTIME <= rg_MTIME + 1;

      if ((verbosity_CLINT != 0) && (rg_MTIME + 1 == rg_MTIMECMP))
	 $display ("%0d: Mems_Devices: timer IRQ from next tick", cur_cycle);
   endrule

   // ================================================================
   // INTERFACE

   method Action init (Initial_Params initial_params) if (! rg_running);
      rg_logfile <= initial_params.flog;
      spec_sto_buf.init (initial_params);
      c_mems_devices_init (initial_params.addr_base_mem, initial_params.size_B_mem);
      rg_MTIME    <= 0;
      rg_MTIMECMP <= '1;
      rg_running <= True;
   endmethod

   method ActionValue #(Bit #(64)) rd_MTIME;
      return rg_MTIME;
   endmethod

   method Bit #(1) mv_MTIP;
      return pack (rg_MTIME >= rg_MTIMECMP);
   endmethod
endmodule

// ****************************************************************
// Imported C functions for a memories-and-devices model
// All devices are accessed just like memory (MMIO).

import "BDPI"
function Action c_mems_devices_init (Bit #(64) addr_base_mem, Bit #(64) size_B_mem);

// result and wdata are passed as pointers.
// result is passed as first arg to C function.
// result is 32-bits of status (MEM_OK, MEM_ERR) followed by rdata.
// client is 0 for IMem, 1 for DMem, 2 for MMIO

import "BDPI"                                                    // \blatex{Mems_Devices}
function ActionValue #(Bit #(96)) c_mems_devices_req_rsp (Bit #(64) inum,
							  Bit #(32) req_type,
							  Bit #(32) req_size,
							  Bit #(64) addr,
							  Bit #(32) client,
							  Bit #(128) wdata);
                                                                 // \elatex{Mems_Devices}
// ****************************************************************

endpackage
