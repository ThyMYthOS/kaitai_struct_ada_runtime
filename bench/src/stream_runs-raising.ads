--  The parsing loop for the design that reports the end of the stream by an
--  exception.  It is kept apart because it needs exception propagation,
--  which a light run-time library does not provide.

package Stream_Runs.Raising is

   function Run_Cursor_Raise (Data : Bytes) return U64
   with No_Inline;

end Stream_Runs.Raising;
