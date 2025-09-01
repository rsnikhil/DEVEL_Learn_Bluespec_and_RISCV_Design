// Copyright (c) 2023-2024 Rishiyur S. Nikhil.  All Rights Reserved.

// WARNING: This file is not a standalone package;
// WARNING: it is "included" into other BSV files

// ****************************************************************
// Drum behavior expressed using explicit rules

   Reg #(CPU_ACTION) rg_action <- mkReg (A_FETCH);              // \blatex{Drum_Rules}

   rule rl_fetch ((rg_runstate == CPU_RUNNING)
		  && (! can_take_intr)
		  && (rg_action == A_FETCH));
      a_Fetch;
      rg_action <= A_DECODE;
   endrule

   rule rl_decode (rg_action == A_DECODE);
      a_Decode;
      rg_action <= A_REGISTER_READ_AND_DISPATCH;
   endrule

   rule rl_register_read_and_dispatch (rg_action == A_REGISTER_READ_AND_DISPATCH);
      a_Register_Read_and_Dispatch;
      rg_action <= A_EX;
   endrule

   rule rl_Retire_direct ((rg_action == A_EX)
			  && (rg_Dispatch.to_Retire.exec_tag == EXEC_TAG_DIRECT));
      a_Retire_direct;
      rg_action <= A_EXCEPTION;
   endrule

   // BRANCH, JAL, JALR
   rule rl_EX_Control ((rg_action == A_EX)
		       && (rg_Dispatch.to_Retire.exec_tag == EXEC_TAG_CONTROL));
      a_EX_Control;
      rg_action <= A_RETIRE_CONTROL;
   endrule

   rule rl_Retire_Control (rg_action == A_RETIRE_CONTROL);
      a_Retire_Control;
      rg_action <= A_EXCEPTION;
   endrule

   // LUI, AUIPC, IALU
   rule rl_EX_Int ((rg_action == A_EX)
		   && (rg_Dispatch.to_Retire.exec_tag ==  EXEC_TAG_INT));
      a_EX_Int;
      rg_action <= A_RETIRE_INT;
   endrule

   rule rl_Retire_Int (rg_action == A_RETIRE_INT);
      a_Retire_Int;
      rg_action <= A_EXCEPTION;
   endrule

   // rule rl_EX_DMem (rg_action == A_EX_DMEM);
   rule rl_EX_DMem ((rg_action == A_EX)
		    && (rg_Dispatch.to_Retire.exec_tag == EXEC_TAG_DMEM));
      a_EX_DMem;
      rg_action <= A_RETIRE_DMEM;
   endrule

   rule rl_Retire_DMem (rg_action == A_RETIRE_DMEM);
      a_Retire_DMem;
      rg_action <= A_EXCEPTION;
   endrule

   rule rl_exception (rg_action == A_EXCEPTION);
      if (rg_exception)
	 a_exception;
      rg_action <= A_FETCH;
   endrule
                                                                // \elatex{Drum_Rules}

   rule rl_take_interrupt ((rg_runstate == CPU_RUNNING)
			   && (! can_take_intr));
      a_interrupt (cause);
   endrule

   rule rl_halt (rg_runstate == CPU_HALTREQ);
      csrs.save_dpc_dcsr_cause_prv (rg_pc, rg_dcsr_cause, priv_M);
      rg_runstate <= CPU_HALTED;
   endrule

// ****************************************************************
