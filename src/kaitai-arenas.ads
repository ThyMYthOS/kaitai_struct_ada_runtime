--  Storage for byte arrays that a parser has to make, such as the result of
--  a "process" routine.  The storage is an array of the caller; an arena
--  only keeps track of how much of it is in use, in the same way as a
--  stream keeps a position in a buffer it does not own.  Bytes are handed
--  out from the front and are given back all at once or down to a mark.
--
--     Storage : Bytes (1 .. 4096) := (others => 0);
--     A       : Arena := Open (Storage);
--     ...
--     Reserve (A, Size (Item), Result, OK);
--     if OK then
--        Xor_One (Buffer (Item.First .. Item.Last), Key, Storage (Result.First .. Result.Last));
--     end if;
--
--  The result is then read like any other data, with Storage as the buffer.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Arenas
  with Pure, SPARK_Mode, Always_Terminates
is

   type Arena is private;

   --  Number of bytes the storage has
   function Capacity (A : Arena) return Length;

   --  Number of bytes handed out
   function Used (A : Arena) return Length
   with Post => Used'Result <= Capacity (A);

   --  Number of bytes that can still be handed out
   function Available (A : Arena) return Length
   is (Capacity (A) - Used (A));

   --  The bytes handed out so far, as a slice of the storage
   function In_Use (A : Arena) return Slice
   with Post => Size (In_Use'Result) = Used (A);

   --  True if A was opened on storage with the bounds of Storage
   function Is_Valid (A : Arena; Storage : Bytes) return Boolean
   with Post => (if Is_Valid'Result then Within (In_Use (A), Storage));

   --  True if Left and Right are arenas for the same storage.  An arena
   --  that is valid for some storage stays so in all operations.
   function Same_Storage (Left, Right : Arena) return Boolean
   with
     Ghost,
     Post =>
       (if Same_Storage'Result
        then Capacity (Left) = Capacity (Right) and then In_Use (Left).First = In_Use (Right).First);

   --  True if Item lies in the bytes handed out
   function Holds (A : Arena; Item : Slice) return Boolean
   is (Is_Empty (Item) or else (Item.First >= In_Use (A).First and then Item.Last <= In_Use (A).Last));

   --  An arena for Storage with nothing handed out
   function Open (Storage : Bytes) return Arena
   with Inline, Post => Is_Valid (Open'Result, Storage) and then Used (Open'Result) = 0;

   --  Hand out the next Count bytes.  OK is False if fewer are available;
   --  nothing changes then and Item is empty.
   procedure Reserve (A : in out Arena; Count : Length; Item : out Slice; OK : out Boolean)
   with
     Inline,
     Post =>
       OK = (Count <= Available (A'Old))
       and then Same_Storage (A'Old, A)
       and then Holds (A, Item)
       and then (if OK
                 then
                   Used (A) = Used (A'Old) + Count
                   and then Size (Item) = Count
                   and then Item.First = In_Use (A'Old).Last + 1
                 else Used (A) = Used (A'Old) and then Is_Empty (Item));

   --  Hand out as many bytes as Source has and copy Source to them
   procedure Store (Storage : in out Bytes; A : in out Arena; Source : Bytes; Item : out Slice; OK : out Boolean)
   with
     Pre  => Is_Valid (A, Storage),
     Post =>
       OK = (Source'Length <= Available (A'Old))
       and then Same_Storage (A'Old, A)
       and then Is_Valid (A, Storage)
       and then Holds (A, Item)
       and then (if OK
                 then
                   Used (A) = Used (A'Old) + Source'Length
                   and then Size (Item) = Source'Length
                   and then Item.First = In_Use (A'Old).Last + 1
                   and then (for all I in Storage'Range =>
                               Storage (I)
                               = (if I in Item.First .. Item.Last
                                  then Source (Source'First + (I - Item.First))
                                  else Storage'Old (I)))
                 else Used (A) = Used (A'Old) and then Is_Empty (Item) and then Storage = Storage'Old);

   --  A value to give back to with Release
   function Mark (A : Arena) return Length
   is (Used (A));

   --  Give back all bytes handed out since Used was To.  Slices handed out
   --  since then must not be used any more.
   procedure Release (A : in out Arena; To : Length)
   with Inline, Pre => To <= Used (A), Post => Used (A) = To and then Same_Storage (A'Old, A);

   --  Give back all bytes
   procedure Reset (A : in out Arena)
   with Inline, Post => Used (A) = 0 and then Same_Storage (A'Old, A);

private

   --  First .. Last are the indices of the storage, Next is the index of
   --  the first byte that is not handed out.
   type Arena is record
      First : Length := 1;
      Last  : Length := 0;
      Next  : Length := 1;
   end record
   with
     Predicate =>
       Arena.First >= 1
       and then Arena.Last < Length'Last
       and then Arena.Last >= Arena.First - 1
       and then Arena.Next >= Arena.First
       and then Arena.Next - 1 <= Arena.Last;

   function Capacity (A : Arena) return Length
   is (A.Last - A.First + 1);

   function Used (A : Arena) return Length
   is (A.Next - A.First);

   function In_Use (A : Arena) return Slice
   is (First => A.First, Last => A.Next - 1);

   function Same_Storage (Left, Right : Arena) return Boolean
   is (Left.First = Right.First and then Left.Last = Right.Last);

   function Is_Valid (A : Arena; Storage : Bytes) return Boolean
   is (if Storage'Length = 0 then A.Last = A.First - 1 else A.First = Storage'First and then A.Last = Storage'Last);

end Kaitai.Arenas;
