with Extras;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Test_Support;   use Test_Support;

package body Extras_Tests is

   package Nodes renames Extras.Node_Type;
   package Items renames Extras.Item_Type;

   Data : constant Bytes (1 .. 26) :=
     (16#5A#,          --   0  key
      16#02#,          --   1  len_secret
      16#3B#,
      16#38#,          --   2  secret: "ab" xor key
      16#03#,          --   4  len_packed
      16#42#,
      16#86#,
      16#CA#,          --   5  packed: 12 34 56 rotated right by 3
      16#01#,
      16#02#,          --   8  items[0].value, as long as secret
      16#0A#,          --  10  items[0].extra, because key > 1
      16#04#,
      16#05#,          --  11  items[1].value
      16#0B#,          --  13  items[1].extra
      16#01#,
      16#02#,          --  14  tree: tag 1, two children
      16#02#,
      16#00#,
      16#07#,          --  16  first child: tag 2, none, weight 7
      16#03#,
      16#01#,          --  19  second child: tag 3, one child
      16#04#,
      16#00#,
      16#08#,          --  21  its child: tag 4, none, weight 8
      16#09#,          --  24  weight of the second child
      16#0C#);         --  25  weight of the tree

   --  A tree in which every node has one child, Levels deep below its
   --  root.  The key is 0, so there are no weights.
   Deep : Bytes (1 .. 3 + 2 * 40) := (others => 0);

   function Chain (Levels : Length) return Length
   with Pre => Levels < 40;

   function Chain (Levels : Length) return Length is
   begin
      Deep := (others => 0);
      for I in 0 .. Levels - 1 loop
         Deep (4 + 2 * I) := Byte (I mod 256);
         Deep (5 + 2 * I) := 1;
      end loop;
      return 3 + 2 * (Levels + 1);
   end Chain;

   procedure Test_Processing is
      S       : Stream := Open (Data);
      R       : Extras.T;
      Target  : Bytes (41 .. 50) := (others => 16#EE#);
      Last    : Length;
      Outcome : Status_Kind;
      Inner   : Extras.Inner_Type.T;
   begin
      Group ("Extras processing");
      Extras.Parse (R, Data, S);
      Check (OK (S) and then Is_EOF (S), "parsed to the end");
      if not Extras.Valid (R) then
         Check (False, "valid");
         return;
      end if;
      Check (Extras.Secret_Raw (R) = (First => 3, Last => 4), "the bytes as they are in the input");
      Extras.Secret (R, Data, Target, Last, Outcome);
      Check (Outcome = Success and then Last = 42, "processed into the array of the caller");
      Check (Target (41 .. 42) = (16#61#, 16#62#), "with the key taken from a field");
      Check (Target (43) = 16#EE#, "and nothing written behind it");
      Extras.Secret (R, Data, Target (41 .. 41), Last, Outcome);
      Check (Outcome = Capacity_Exceeded and then Last = 40, "an array that is too small");

      Extras.Packed (R, Data, Target, Inner, Outcome);
      Check (Outcome = Success and then Extras.Inner_Type.Valid (Inner), "a value parsed from processed bytes");
      if Extras.Inner_Type.Valid (Inner) then
         Check (Extras.Inner_Type.A (Inner) = 16#1234# and then Extras.Inner_Type.B (Inner) = 16#56#, "its fields");
      end if;
      Extras.Packed (R, Data, Target (41 .. 42), Inner, Outcome);
      Check (Outcome = Capacity_Exceeded and then not Extras.Inner_Type.Valid (Inner), "storage that is too small");
   end Test_Processing;

   procedure Test_References is
      S     : Stream := Open (Data);
      R     : Extras.T;
      Item  : Items.T;
      Other : Bytes := Data;
   begin
      Group ("Extras references to parent and root");
      Extras.Parse (R, Data, S);
      if not Extras.Valid (R) then
         Check (False, "valid");
         return;
      end if;
      Check (Extras.Items_Count (R) = 2, "count");
      Extras.Get_Items (R, Data, 1, Item);
      if Items.Valid (Item) then
         Check (Items.Value (Item) = (First => 12, Last => 13), "a size taken from the parent");
         Check (Items.Has_Extra (Item) and then Items.Extra (Item) = 16#0B#, "a condition on a field of the root");
      else
         Check (False, "second item is valid");
      end if;

      --  With key 1 the items have no extra byte, so the input has two
      --  bytes too many for the tree to end where the input ends
      Other (1) := 1;
      S := Open (Other);
      Extras.Parse (R, Other, S);
      if Extras.Valid (R) then
         Extras.Get_Items (R, Other, 0, Item);
         Check (Items.Valid (Item) and then not Items.Has_Extra (Item), "the condition does not hold");
         Check (not Is_EOF (S), "and the rest is read differently");
      else
         Check (Status (S) = End_Of_Stream, "or cannot be read at all");
      end if;
   end Test_References;

   procedure Test_Recursion is
      S      : Stream := Open (Data);
      R      : Extras.T;
      Child  : Nodes.T;
      Grand  : Nodes.T;
      Length : Kaitai.Types.Length;
   begin
      Group ("Extras a type that contains itself");
      Extras.Parse (R, Data, S);
      if not Extras.Valid (R) then
         Check (False, "valid");
         return;
      end if;
      Check (Nodes.Tag (Extras.Tree (R)) = 1 and then Nodes.Children_Count (Extras.Tree (R)) = 2, "the root");
      Check (Nodes.Has_Weight (Extras.Tree (R)) and then Nodes.Weight (Extras.Tree (R)) = 16#0C#, "field after");
      Nodes.Get_Children (Extras.Tree (R), Data, 0, Child);
      Check (Nodes.Valid (Child) and then Nodes.Tag (Child) = 2 and then Nodes.Weight (Child) = 7, "first child");
      Nodes.Get_Children (Extras.Tree (R), Data, 1, Child);
      if Nodes.Valid (Child) and then Nodes.Belongs_To (Child, Data) and then Nodes.Children_Count (Child) = 1 then
         Check (Nodes.Tag (Child) = 3 and then Nodes.Weight (Child) = 9, "second child");
         Nodes.Get_Children (Child, Data, 0, Grand);
         Check (Nodes.Valid (Grand) and then Nodes.Tag (Grand) = 4 and then Nodes.Weight (Grand) = 8, "its child");
      else
         Check (False, "second child has a child");
      end if;

      Length := Chain (Extras.Max_Depth);
      S := Open (Deep (1 .. Length));
      Extras.Parse (R, Deep (1 .. Length), S);
      Check (OK (S) and then Extras.Valid (R) and then Is_EOF (S), "nested as deep as is allowed");
      Length := Chain (Extras.Max_Depth + 1);
      S := Open (Deep (1 .. Length));
      Extras.Parse (R, Deep (1 .. Length), S);
      Check (Status (S) = Limit_Exceeded and then not Extras.Valid (R), "nested one level deeper");
   end Test_Recursion;

   procedure Test_Truncation is
      S   : Stream;
      R   : Extras.T;
      Bad : Natural := 0;
   begin
      Group ("Extras variations");
      for Last in 0 .. Data'Last - 1 loop
         S := Open (Data (1 .. Last));
         Extras.Parse (R, Data (1 .. Last), S);
         if Extras.Valid (R) or else Status (S) /= End_Of_Stream then
            Bad := Bad + 1;
         end if;
      end loop;
      Check (Bad = 0, "every shorter input fails");
   end Test_Truncation;

   procedure Run is
   begin
      Test_Processing;
      Test_References;
      Test_Recursion;
      Test_Truncation;
   end Run;

end Extras_Tests;
