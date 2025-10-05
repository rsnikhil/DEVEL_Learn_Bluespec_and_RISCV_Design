// Copyright (c) 2023-2025 Rishiyur S. Nikhil.  All Rights Reserved.

package Fn_Fetch;

// ****************************************************************
// Fetch stage

// ****************************************************************
// Imports from libraries

// None

// ----------------
// Local imports

import Utils       :: *;
import Arch        :: *;
import Instr_Bits  :: *;
import Mem_Req_Rsp :: *;
import Inter_Stage :: *;

// ****************************************************************
// Fetch: Functionality

typedef struct {                                // \blatex{Result_F}
   Fetch_to_Decode  to_D;
   Mem_Req          mem_req;
} Result_F
deriving (Bits, FShow);                         // \elatex{Result_F}

// This is actually a pure function; is ActionValue only to allow
// $display insertion for debugging
function ActionValue #(Result_F)                                     // \blatex{fn_Fetch}
         fn_Fetch (Bit #(XLEN)  pc,
		   Bit #(XLEN)  predicted_pc,    // \belide{19}
		   Epoch        epoch,
		   Bit #(64)    inum,
		   Bit #(64)    arch_inum,
		   File         flog);           // \eelide
   actionvalue
      Result_F y = ?;
      // Info to next stage
      y.to_D = Fetch_to_Decode {pc:            pc,
				predicted_pc:  predicted_pc,          // \belide{32}
				epoch:         epoch,
				halt_sentinel: False,

				xtra: Fetch_to_Decode_Xtra {
				   inum: inum
			        }                                     // \eelide
	                       };                                    

      // Request to IMem
      y.mem_req = Mem_Req {req_type: funct5_FETCH,
			   size:     MEM_4B,
			   addr:     zeroExtend (pc),
                                                                      // \belide{27}
			   data :    arch_inum,    // For debugging/TestRIG only
			   epoch:    epoch,        // Not required for Fetch
			   xtra: Mem_Req_Xtra {
			      inum:   inum,
			      pc:     pc,
			      instr:  ?}                              // \eelide
			   };
      return y;
   endactionvalue
endfunction                                                          //  \elatex{fn_Fetch}

// ****************************************************************
// Logging actions

function Action log_Fetch (File flog, Fetch_to_Decode to_D, Mem_Req mem_req);
   action
      wr_log (flog, $format ("CPU.Fetch:"));
      wr_log_cont (flog, $format ("    ", fshow_Fetch_to_Decode (to_D)));
      wr_log_cont (flog, $format ("    ", fshow_Mem_Req (mem_req)));
      ftrace (flog, to_D.xtra.inum, to_D.pc, 0, "F", $format(""));
   endaction
endfunction

function Action log_Redirect (File flog, Fetch_from_Retire x);
   action
      wr_log (flog, $format ("CPU.Redirect:"));
      wr_log_cont (flog, $format ("    ", fshow_Fetch_from_Retire (x)));
      ftrace (flog, x.xtra.inum, x.xtra.pc, x.xtra.instr, "Redir", $format(""));
   endaction
endfunction

// ****************************************************************

endpackage
