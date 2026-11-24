with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Sample_Parser;  use Sample_Parser;
with Test_Support;   use Test_Support;

package body Sample_Parser_Tests is

   --  magic, version 2, flags 16#80#, length 3, id -2, payload AA BB CC,
   --  and one byte that does not belong to the message
   Good : constant Bytes (5 .. 24) :=
     (16#4B#,
      16#53#,
      16#02#,
      16#80#,
      16#03#,
      16#00#,
      16#00#,
      16#00#,
      16#FF#,
      16#FF#,
      16#FF#,
      16#FF#,
      16#FF#,
      16#FF#,
      16#FF#,
      16#FE#,
      16#AA#,
      16#BB#,
      16#CC#,
      16#11#);

   type Parser is access procedure (Buffer : Bytes; S : in out Stream; Result : out Message);

   procedure Test (Name : String; Parse : Parser) is
      S   : Stream := Open (Good);
      M   : Message;
      Bad : Bytes := Good;
   begin
      Group (Name);
      Parse (Good, S, M);
      Check (OK (S), "a good message parses");
      Check (M.Version = 2 and then M.Flags = 16#80# and then M.Size = 3 and then M.Id = -2, "header fields");
      Check (M.Payload.First = 21 and then M.Payload.Last = 23, "payload position");
      Check (Good (M.Payload.First .. M.Payload.Last) = (16#AA#, 16#BB#, 16#CC#), "payload content");
      Check (Pos (S) = 19 and then Remaining (S) = 1, "the stream stops after the message");

      --  Every truncation of the message must fail cleanly
      for Last in Good'First - 1 .. Good'Last - 2 loop
         S := Open (Good (Good'First .. Last));
         Parse (Good (Good'First .. Last), S, M);
         Check (Status (S) = End_Of_Stream, "a truncated message runs out of bytes");
         Check (Is_Empty (M.Payload), "a truncated message has no payload");
      end loop;

      Bad (Bad'First) := 16#4C#;
      S := Open (Bad);
      Parse (Bad, S, M);
      Check (Status (S) = Validation_Not_Equal, "a wrong magic is a validation failure");

      --  A length field larger than any buffer
      Bad := Good;
      Bad (Bad'First + 4 .. Bad'First + 7) := (others => 16#FF#);
      S := Open (Bad);
      Parse (Bad, S, M);
      Check (Status (S) = End_Of_Stream, "a huge length runs out of bytes");
   end Test;

   procedure Run is
   begin
      Test ("Sample_Parser.Parse", Parse'Access);
      Test ("Sample_Parser.Parse_Block", Parse_Block'Access);
   end Run;

end Sample_Parser_Tests;
