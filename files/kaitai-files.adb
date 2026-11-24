with Ada.Streams.Stream_IO;

package body Kaitai.Files
  with SPARK_Mode => Off
is

   use Ada.Streams;

   --  Size of an open file, or that it is too large to be counted
   procedure Size_Of (File : Stream_IO.File_Type; Size : out Length; Result : out Result_Kind) is
      Count : constant Stream_IO.Count := Stream_IO.Size (File);
   begin
      if Long_Long_Integer (Count) > Long_Long_Integer (Length'Last - 1) then
         Size := 0;
         Result := Too_Large;
      else
         Size := Length (Count);
         Result := Done;
      end if;
   end Size_Of;

   procedure Get_Size (Name : String; Size : out Length; Result : out Result_Kind) is
      File : Stream_IO.File_Type;
   begin
      Size := 0;
      begin
         Stream_IO.Open (File, Stream_IO.In_File, Name);
      exception
         when others =>
            Result := Cannot_Open;
            return;
      end;
      begin
         Size_Of (File, Size, Result);
         Stream_IO.Close (File);
      exception
         when others =>
            Size := 0;
            Result := Cannot_Open;
      end;
   end Get_Size;

   procedure Read (Name : String; Buffer : in out Bytes; Last : out Length; Result : out Result_Kind) is
      File : Stream_IO.File_Type;
      Size : Length;
   begin
      Last := Buffer'First - 1;
      begin
         Stream_IO.Open (File, Stream_IO.In_File, Name);
      exception
         when others =>
            Result := Cannot_Open;
            return;
      end;
      begin
         Size_Of (File, Size, Result);
         if Result = Done and then Size > Buffer'Length then
            Result := Too_Large;
         end if;
         if Result = Done and then Size > 0 then
            declare
               --  The bytes of Buffer seen as stream elements; both are
               --  arrays of bytes without gaps
               Item : Stream_Element_Array (1 .. Stream_Element_Offset (Size))
               with Import, Address => Buffer (Buffer'First)'Address;
               Got  : Stream_Element_Offset;
            begin
               Stream_IO.Read (File, Item, Got);
               if Got = Item'Last then
                  Last := Buffer'First + (Size - 1);
               else
                  Result := Failed;
               end if;
            end;
         end if;
         Stream_IO.Close (File);
      exception
         when others =>
            Last := Buffer'First - 1;
            Result := Failed;
      end;
   end Read;

end Kaitai.Files;
