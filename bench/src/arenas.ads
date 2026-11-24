--  Two arena implementations on top of the Ada storage pool mechanism:
--
--    Bump_Pool   : a plain user-defined storage pool (Ada 95), released as
--                  a whole with Release.
--    Subpool_Pool: an Ada 2012 pool with subpools (RM 13.11.4).  Objects are
--                  allocated with "new (Handle) T" and a subpool is released
--                  with Ada.Unchecked_Deallocate_Subpool.
--
--  Both allocate by bumping a pointer inside chunks obtained from the heap
--  and never free single objects.

with System;
with System.Storage_Elements; use System.Storage_Elements;
with System.Storage_Pools;
with System.Storage_Pools.Subpools;

package Arenas is

   Default_Chunk_Size : constant Storage_Count := 64 * 1024;

   type Bump_Pool is new System.Storage_Pools.Root_Storage_Pool with private;

   overriding
   procedure Allocate
     (Pool : in out Bump_Pool; Address : out System.Address; Size : Storage_Count; Alignment : Storage_Count);

   overriding
   procedure Deallocate
     (Pool : in out Bump_Pool; Address : System.Address; Size : Storage_Count; Alignment : Storage_Count)
   is null;

   overriding
   function Storage_Size (Pool : Bump_Pool) return Storage_Count
   is (Storage_Count'Last);

   --  Free everything allocated from Pool
   procedure Release (Pool : in out Bump_Pool);

   --  Invalidate everything allocated from Pool, but keep the memory for
   --  later allocations instead of returning it to the heap
   procedure Reset (Pool : in out Bump_Pool);

   type Subpool_Pool is new System.Storage_Pools.Subpools.Root_Storage_Pool_With_Subpools with private;

   overriding
   function Create_Subpool (Pool : in out Subpool_Pool) return not null System.Storage_Pools.Subpools.Subpool_Handle;

   overriding
   procedure Allocate_From_Subpool
     (Pool      : in out Subpool_Pool;
      Address   : out System.Address;
      Size      : Storage_Count;
      Alignment : Storage_Count;
      Subpool   : not null System.Storage_Pools.Subpools.Subpool_Handle);

   overriding
   procedure Deallocate_Subpool
     (Pool : in out Subpool_Pool; Subpool : in out System.Storage_Pools.Subpools.Subpool_Handle);

private

   type Chunk;
   type Chunk_Access is access Chunk;

   type Chunk (Size : Storage_Count) is record
      Next : Chunk_Access;
      Data : aliased Storage_Array (1 .. Size);
   end record;

   type Chunk_List is record
      Head  : Chunk_Access;
      Used  : Storage_Count := 0;
      Spare : Chunk_Access;   --  chunks kept by Reset for reuse
   end record;

   type Bump_Pool is new System.Storage_Pools.Root_Storage_Pool with record
      Chunks : Chunk_List;
   end record;

   type Subpool_Pool is new System.Storage_Pools.Subpools.Root_Storage_Pool_With_Subpools with null record;

   type Arena_Subpool is new System.Storage_Pools.Subpools.Root_Subpool with record
      Chunks : Chunk_List;
   end record;

end Arenas;
