package body Hello_World
  with SPARK_Mode
is

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
      --  Work on a copy of the stream; see docs/codegen.md
      L : Stream := S;
   begin
      Read_U1 (Buffer, L, This.One);
      This.Is_Valid := OK (L);
      S := L;
   end Parse;

end Hello_World;
