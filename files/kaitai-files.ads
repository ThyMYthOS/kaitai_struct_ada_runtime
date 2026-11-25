--  Reading a file into a buffer, for programs that parse files.  The buffer
--  is an array of the caller, as everywhere in this library; Get_Size tells
--  how large it has to be.
--
--  This package is in a project of its own, kaitai_struct_files.gpr, since
--  it needs a run-time library with a file system.  Its body is not in
--  SPARK, because it handles the exceptions of Ada.Streams.Stream_IO; what
--  the specification promises is checked by tests, not by proof.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Files
  with SPARK_Mode
is

   --  How an operation ended
   type Result_Kind is
     (Done,         --  the operation succeeded
      Cannot_Open,   --  there is no such file, or it may not be read
      Too_Large,     --  the file has more bytes than the buffer or than a Length can count
      Failed);       --  reading stopped before the end of the file

   --  Number of bytes in the file
   procedure Get_Size (Name : String; Size : out Length; Result : out Result_Kind)
   with Post => Result in Done | Cannot_Open | Too_Large and then (if Result /= Done then Size = 0);

   --  Read the whole file into Buffer, starting at its first byte.  On Done
   --  the file is in Buffer (Buffer'First .. Last), and Last is
   --  Buffer'First - 1 for an empty file.  Otherwise Last is
   --  Buffer'First - 1 as well and Buffer holds nothing of use.
   procedure Read (Name : String; Buffer : in out Bytes; Last : out Length; Result : out Result_Kind)
   with
     Pre  => Buffer'First >= 1,
     Post =>
       Last >= Buffer'First - 1
       and then Last <= Buffer'Last
       and then (if Result /= Done or else Buffer'Length = 0 then Last = Buffer'First - 1);

end Kaitai.Files;
