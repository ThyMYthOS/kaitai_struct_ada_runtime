with Decoding_Tests;
with Sample_Parser_Tests;
with Streams_Tests;
with Test_Support;

procedure All_Tests is
begin
   Decoding_Tests.Run;
   Streams_Tests.Run;
   Sample_Parser_Tests.Run;
   Test_Support.Summary;
end All_Tests;
