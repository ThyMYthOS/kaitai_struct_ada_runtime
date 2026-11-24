--  Parser for hello_world.ksy, translated by hand in the way the Kaitai
--  Struct compiler is meant to generate it.  See docs/codegen.md.

with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

package Hello_World
  with SPARK_Mode, Always_Terminates
is

   type T is private;

   --  True if This holds the result of a successful Parse
   function Valid (This : T) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with Pre => Is_Valid (S, Buffer), Post => Is_Valid (S, Buffer) and then Valid (This) = OK (S);

   function One (This : T) return U8
   with Pre => Valid (This);

private

   type T is record
      Is_Valid : Boolean := False;
      One      : U8 := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function One (This : T) return U8
   is (This.One);

end Hello_World;
