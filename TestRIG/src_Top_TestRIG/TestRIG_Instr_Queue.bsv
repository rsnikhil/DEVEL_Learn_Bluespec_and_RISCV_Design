// Copyright (c) 2025 Rishiyur S. Nikhil.  All Rights Reserved.

package TestRIG_Instr_Queue;

// ****************************************************************
// This package implements a queue of incoming instructions from
// TestRIG, for direct injection into the CPU pipeline, with "bounded
// rewindability" due to the CPU pipeline discarding instructions due
// to redirections (mispredictions, traps, ...).

// ****************************************************************
// Imports from libraries

import RegFile :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;

// ----------------
// Local imports

// None

// ****************************************************************

Integer verbosity = 1;

// ****************************************************************
// INTERFACE

interface TestRIG_Instr_Queue_IFC;
   // Enqueue an instruction arriving from TestRIG
   method Action enq (Bit #(32) instr);

   // Dequeue an instruction for injection into the CPU
   method ActionValue #(Maybe #(Bit #(32))) try_deq (Bit #(64) arch_inum);

   // Debugging
   method Tuple2 #(Bit #(64), Bit #(64)) mv_q_tl_size;
endinterface

// ****************************************************************
// Queue parameters

// QCapacity must be power of two so we can use bit-masking to compute
// index of the circular queue
typedef 16 QCapacity;
Integer qcapacity = valueof (QCapacity);

typedef Bit #(TLog #(QCapacity)) QIndex;

// ****************************************************************
// IMPLEMENTATION MODULE

(* synthesize *)
module mkTestRIG_Instr_Queue (TestRIG_Instr_Queue_IFC);
   // The Queue (register file holding a circular queue)
   RegFile #(QIndex, Bit #(32)) rf_queue <- mkRegFileFull;

   // Index for next enq (monotonically increasing; use LSBs to locate in queue)
   Reg #(Bit #(64)) rg_tl <- mkReg (0);

   // Current queue occupancy (0..qcapacity)
   // TODO: replace with CReg for simultaneous enq/deq
   Reg #(Bit #(64)) rg_qsize <- mkReg (0);

   // ================================================================
   // INTERFACE

   // Enqueue an instruction arriving from TestRIG
   method Action enq (Bit #(32) instr) if (rg_qsize < fromInteger (qcapacity));
      QIndex idx_tl = truncate (rg_tl);
      rf_queue.upd (idx_tl, instr);
      rg_tl    <= rg_tl + 1;
      rg_qsize <= rg_qsize + 1;
   endmethod

   // Dequeue an instruction for injection into the CPU.
   // Legal values of arch_inum are (rg_tl - rg_qsize, rg_tl-1)
   method ActionValue #(Maybe #(Bit #(32))) try_deq (Bit #(64) arch_inum) if (rg_qsize != 0);
      actionvalue
	 Bool arch_inum_too_low = (arch_inum < (rg_tl - rg_qsize));
	 if (arch_inum_too_low) begin
	    $display ("INTERNAL ERROR: TestRIG_Instr_Queue: arch_inum arg to 'deq' too low");
	    $display ("    arch_inum %0d < %0d (= rg_tl %0d -  rg_qsize %0d)",
		      arch_inum, rg_tl - rg_qsize, rg_tl, rg_qsize);
	    $finish (1);
	 end

	 if (rg_tl <= arch_inum)
	    return tagged Invalid;
	 else begin
	    QIndex idx_deq = truncate (arch_inum);
	    Bit #(32) instr = rf_queue.sub (idx_deq);

	    // If dequeuing the newest item, advance the queue
	    if ((arch_inum == rg_tl - 1) && (rg_qsize == fromInteger (qcapacity)))
	       rg_qsize <= rg_qsize - 1;

	    return tagged Valid instr; 
	 end
      endactionvalue
   endmethod

   method Tuple2 #(Bit #(64), Bit #(64)) mv_q_tl_size;
      return tuple2 (rg_tl, rg_qsize);
   endmethod
endmodule

// ****************************************************************

endpackage
