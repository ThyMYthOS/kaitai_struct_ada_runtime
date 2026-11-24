with Ada.Streams.Stream_IO;
with Kaitai.Files; use Kaitai.Files;
with Kaitai.Types; use Kaitai.Types;
with Test_Support; use Test_Support;

package body Files_Tests is

   Name  : constant String := "obj/files_tests.tmp";
   Empty : constant String := "obj/files_tests_empty.tmp";

   procedure Write (File_Name : String; Count : Natural) is
      use Ada.Streams;
      File : Stream_IO.File_Type;
      Item : Stream_Element_Array (1 .. Stream_Element_Offset (Count));
   begin
      for I in Item'Range loop
         Item (I) := Stream_Element ((I * 7) mod 256);
      end loop;
      Stream_IO.Create (File, Stream_IO.Out_File, File_Name);
      Stream_IO.Write (File, Item);
      Stream_IO.Close (File);
   end Write;

   procedure Run is
      Buffer : Bytes (11 .. 310) := (others => 16#EE#);
      Size   : Length;
      Last   : Length;
      Result : Result_Kind;
      Wrong  : Natural := 0;
   begin
      Group ("Files");
      Write (Name, 300);
      Write (Empty, 0);

      Get_Size (Name, Size, Result);
      Check (Result = Done and then Size = 300, "size of a file");
      Get_Size (Empty, Size, Result);
      Check (Result = Done and then Size = 0, "size of an empty file");
      Get_Size ("obj/no_such_file.tmp", Size, Result);
      Check (Result = Cannot_Open and then Size = 0, "size of a file that is not there");

      Read (Name, Buffer, Last, Result);
      Check (Result = Done and then Last = 310, "a file that fills the buffer");
      for I in Buffer'Range loop
         if Buffer (I) /= Byte (((I - 10) * 7) mod 256) then
            Wrong := Wrong + 1;
         end if;
      end loop;
      Check (Wrong = 0, "every byte is in its place");

      Buffer := (others => 16#EE#);
      Read (Name, Buffer (11 .. 309), Last, Result);
      Check (Result = Too_Large and then Last = 10, "a buffer one byte too small");
      Check (Buffer (11) = 16#EE# and then Buffer (310) = 16#EE#, "nothing is read then");

      Write (Name, 5);
      Read (Name, Buffer (101 .. 200), Last, Result);
      Check (Result = Done and then Last = 105, "a file shorter than the buffer");
      Check (Buffer (101) = 7 and then Buffer (105) = 35, "is at the start of the buffer");
      Check (Buffer (100) = 16#EE# and then Buffer (106) = 16#EE#, "and nothing around it changed");

      Read (Empty, Buffer, Last, Result);
      Check (Result = Done and then Last = 10, "an empty file");
      Read (Empty, Buffer (50 .. 49), Last, Result);
      Check (Result = Done and then Last = 49, "an empty file into an empty buffer");
      Read (Name, Buffer (50 .. 49), Last, Result);
      Check (Result = Too_Large and then Last = 49, "a file into an empty buffer");
      Read ("obj/no_such_file.tmp", Buffer, Last, Result);
      Check (Result = Cannot_Open and then Last = 10, "a file that is not there");
      Read ("obj", Buffer, Last, Result);
      Check (Result /= Done and then Last = 10, "a directory is not a file");
   end Run;

end Files_Tests;
