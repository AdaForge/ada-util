-----------------------------------------------------------------------
--  util-http-clients-tests -- Unit tests for HTTP client
--  Copyright (C) 2012, 2020 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------
with Ada.Unchecked_Deallocation;

with Util.Test_Caller;

with Util.Strings.Transforms;
with Util.Http.Tools;
with Util.Strings;
with Util.Log.Loggers;

package body Util.Http.Clients.Tests is

   --  The logger
   Log : constant Util.Log.Loggers.Logger := Util.Log.Loggers.Create ("Util.Http.Clients.Tests");

   package body Http_Tests is
      package Caller is new Util.Test_Caller (Http_Test, "Http-" & NAME);

      procedure Add_Tests (Suite : in Util.Tests.Access_Test_Suite) is
      begin
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Get",
                          Test_Http_Get'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Head",
                          Test_Http_Head'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Post",
                          Test_Http_Post'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Put",
                          Test_Http_Put'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Delete",
                          Test_Http_Delete'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Options",
                          Test_Http_Options'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Patch",
                          Test_Http_Patch'Access);
         Caller.Add_Test (Suite, "Test Util.Http.Clients." & NAME & ".Get (timeout)",
                          Test_Http_Timeout'Access);
      end Add_Tests;

      overriding
      procedure Set_Up (T : in out Http_Test) is
      begin
         Test (T).Set_Up;
         Register;
      end Set_Up;

   end Http_Tests;

   overriding
   procedure Set_Up (T : in out Test) is
   begin
      Log.Info ("Starting test server");
      T.Server := new Test_Server;
      T.Server.Start;
   end Set_Up;

   overriding
   procedure Tear_Down (T : in out Test) is
      procedure Free is
         new Ada.Unchecked_Deallocation (Object => Test_Server'Class,
                                         Name   => Test_Server_Access);
   begin
      if T.Server /= null then
         Log.Info ("Stopping test server");
         T.Server.Stop;
         Free (T.Server);
         T.Server := null;
      end if;
   end Tear_Down;

   --  ------------------------------
   --  Process the line received by the server.
   --  ------------------------------
   overriding
   procedure Process_Line (Into   : in out Test_Server;
                           Line   : in Ada.Strings.Unbounded.Unbounded_String;
                           Stream : in out Util.Streams.Texts.Reader_Stream'Class;
                           Client : in out Util.Streams.Sockets.Socket_Stream'Class) is
      L   : constant String := Ada.Strings.Unbounded.To_String (Line);
      Pos : Natural := Util.Strings.Index (L, ' ');
   begin
      if Pos > 0 and Into.Method = UNKNOWN then
         if L (L'First .. Pos - 1) = "GET" then
            Into.Method := GET;
         elsif L (L'First .. Pos - 1) = "HEAD" then
            Into.Method := HEAD;
         elsif L (L'First .. Pos - 1) = "POST" then
            Into.Method := POST;
         elsif L (L'First .. Pos - 1) = "PUT" then
            Into.Method := PUT;
         elsif L (L'First .. Pos - 1) = "DELETE" then
            Into.Method := DELETE;
         elsif L (L'First .. Pos - 1) = "OPTIONS" then
            Into.Method := OPTIONS;
         elsif L (L'First .. Pos - 1) = "PATCH" then
            Into.Method := PATCH;
         else
            Into.Method := UNKNOWN;
         end if;
      end if;

      Pos := Util.Strings.Index (L, ':');
      if Pos > 0 then
         if L (L'First .. Pos) = "Content-Type:" then
            Into.Content_Type
              := Ada.Strings.Unbounded.To_Unbounded_String (L (Pos + 2 .. L'Last - 2));
         elsif L (L'First .. Pos) = "Content-Length:" then
            Into.Length := Natural'Value (L (Pos + 1 .. L'Last - 2));

         end if;
      end if;

      --  Don't answer if we check the timeout.
      if Into.Test_Timeout then
         return;
      end if;
      if L'Length = 2 and then Into.Length > 0 then
         for I in 1 .. Into.Length loop
            declare
               C : Character;
            begin
               Stream.Read (C);
               Ada.Strings.Unbounded.Append (Into.Result, C);
            end;
         end loop;
         declare
            Output : Util.Streams.Texts.Print_Stream;
         begin
            Output.Initialize (Client'Unchecked_Access);
            Output.Write ("HTTP/1.1 200 Found" & ASCII.CR & ASCII.LF);
            Output.Write ("Content-Length: 4" & ASCII.CR & ASCII.LF);
            Output.Write (ASCII.CR & ASCII.LF);
            Output.Write ("OK" & ASCII.CR & ASCII.LF);
            Output.Flush;
         end;
      elsif L'Length = 2 then
         declare
            Output : Util.Streams.Texts.Print_Stream;
         begin
            Output.Initialize (Client'Unchecked_Access);
            Output.Write ("HTTP/1.1 204 No Content" & ASCII.CR & ASCII.LF);
            Output.Write (ASCII.CR & ASCII.LF);
            Output.Flush;
         end;
      end if;
      Log.Info ("Received: {0}", L);
   end Process_Line;

   --  ------------------------------
   --  Get the test server base URI.
   --  ------------------------------
   function Get_Uri (T : in Test) return String is

   begin
      return "http://" & T.Server.Get_Host & ":" & Util.Strings.Image (T.Server.Get_Port);
   end Get_Uri;

   --  ------------------------------
   --  Test the http Get operation.
   --  ------------------------------
   procedure Test_Http_Get (T : in out Test) is
      Request : Client;
      Reply   : Response;
   begin
      Request.Get ("http://www.google.com", Reply);
      Request.Set_Timeout (5.0);
      T.Assert (Reply.Get_Status = 200 or Reply.Get_Status = 302,
                "Get status is invalid: " & Natural'Image (Reply.Get_Status));

      Util.Http.Tools.Save_Response (Util.Tests.Get_Test_Path ("http_get.txt"), Reply, True);

      --  Check the content.
      declare
         Content : constant String := Util.Strings.Transforms.To_Lower_Case (Reply.Get_Body);
      begin
         Util.Tests.Assert_Matches (T, ".*html.*", Content, "Invalid GET content");
      end;

      T.Assert (Reply.Contains_Header ("Content-Type"), "Header Content-Type not found");
      T.Assert (not Reply.Contains_Header ("Content-Type-Invalid-Missing"),
                "Some invalid header found");

      --  Check one header.
      declare
         Content : constant String := Reply.Get_Header ("Content-Type");
      begin
         T.Assert (Content'Length > 0, "Empty Content-Type header");
         Util.Tests.Assert_Matches (T, ".*text/html.*", Content, "Invalid content type");
      end;
   end Test_Http_Get;

   --  ------------------------------
   --  Test the http HEAD operation.
   --  ------------------------------
   procedure Test_Http_Head (T : in out Test) is
      Request : Client;
      Reply   : Response;
   begin
      Request.Head ("http://www.google.com", Reply);
      Request.Set_Timeout (5.0);
      T.Assert (Reply.Get_Status = 200 or Reply.Get_Status = 302,
                "Get status is invalid: " & Natural'Image (Reply.Get_Status));

      Util.Http.Tools.Save_Response (Util.Tests.Get_Test_Path ("http_head.txt"), Reply, True);

      T.Assert (Reply.Contains_Header ("Content-Type"), "Header Content-Type not found");
      T.Assert (not Reply.Contains_Header ("Content-Type-Invalid-Missing"),
                "Some invalid header found");

      --  Check one header.
      declare
         Content : constant String := Reply.Get_Header ("Content-Type");
      begin
         T.Assert (Content'Length > 0, "Empty Content-Type header");
         Util.Tests.Assert_Matches (T, ".*text/html.*", Content, "Invalid content type");
      end;
   end Test_Http_Head;

   --  ------------------------------
   --  Test the http POST operation.
   --  ------------------------------
   procedure Test_Http_Post (T : in out Test) is
      Request : Client;
      Reply   : Response;
      Uri     : constant String := T.Get_Uri;
   begin
      Log.Info ("Post on " & Uri);

      T.Server.Method := UNKNOWN;
      Request.Post (Uri & "/post",
                    "p1=1", Reply);

      T.Assert (T.Server.Method = POST, "Invalid method received by server");
      Util.Tests.Assert_Equals (T, "application/x-www-form-urlencoded", T.Server.Content_Type,
                                "Invalid content type received by server");
      Util.Tests.Assert_Equals (T, "OK" & ASCII.CR & ASCII.LF, Reply.Get_Body, "Invalid response");
      Util.Http.Tools.Save_Response (Util.Tests.Get_Test_Path ("http_post.txt"), Reply, True);

   end Test_Http_Post;

   --  ------------------------------
   --  Test the http PUT operation.
   --  ------------------------------
   procedure Test_Http_Put (T : in out Test) is
      Request : Client;
      Reply   : Response;
      Uri     : constant String := T.Get_Uri;
   begin
      Log.Info ("Put on " & Uri);

      T.Server.Method := UNKNOWN;
      Request.Add_Header ("Content-Type", "application/x-www-form-urlencoded");
      Request.Set_Timeout (1.0);
      T.Assert (Request.Contains_Header ("Content-Type"), "Missing Content-Type");
      Request.Put (Uri & "/put",
                   "p1=1", Reply);

      T.Assert (T.Server.Method = PUT, "Invalid method received by server");
      Util.Tests.Assert_Equals (T, "application/x-www-form-urlencoded", T.Server.Content_Type,
                                "Invalid content type received by server");
      Util.Tests.Assert_Equals (T, "OK" & ASCII.CR & ASCII.LF, Reply.Get_Body, "Invalid response");
      Util.Http.Tools.Save_Response (Util.Tests.Get_Test_Path ("http_put.txt"), Reply, True);

   end Test_Http_Put;

   --  ------------------------------
   --  Test the http DELETE operation.
   --  ------------------------------
   procedure Test_Http_Delete (T : in out Test) is
      Request : Client;
      Reply   : Response;
      Uri     : constant String := T.Get_Uri;
   begin
      Log.Info ("Delete on " & Uri);

      T.Server.Method := UNKNOWN;
      Request.Add_Header ("Content-Type", "application/x-www-form-urlencoded");
      Request.Set_Timeout (1.0);
      T.Assert (Request.Contains_Header ("Content-Type"), "Missing Content-Type");
      Request.Delete (Uri & "/delete", Reply);

      T.Assert (T.Server.Method = DELETE, "Invalid method received by server");
      Util.Tests.Assert_Equals (T, "application/x-www-form-urlencoded", T.Server.Content_Type,
                                "Invalid content type received by server");
      Util.Tests.Assert_Equals (T, "", Reply.Get_Body, "Invalid response");
      Util.Tests.Assert_Equals (T, 204, Reply.Get_Status, "Invalid status response");

   end Test_Http_Delete;

   --  ------------------------------
   --  Test the http OPTIONS operation.
   --  ------------------------------
   procedure Test_Http_Options (T : in out Test) is
      Request : Client;
      Reply   : Response;
      Uri     : constant String := T.Get_Uri;
   begin
      Log.Info ("Delete on " & Uri);

      T.Server.Method := UNKNOWN;
      Request.Add_Header ("Content-Type", "application/x-www-form-urlencoded");
      Request.Set_Timeout (1.0);
      T.Assert (Request.Contains_Header ("Content-Type"), "Missing Content-Type");
      Request.Options (Uri & "/options", Reply);

      T.Assert (T.Server.Method = OPTIONS, "Invalid method received by server");
      Util.Tests.Assert_Equals (T, "application/x-www-form-urlencoded", T.Server.Content_Type,
                                "Invalid content type received by server");
      Util.Tests.Assert_Equals (T, "", Reply.Get_Body, "Invalid response");
      Util.Tests.Assert_Equals (T, 204, Reply.Get_Status, "Invalid status response");

   end Test_Http_Options;

   --  ------------------------------
   --  Test the http PATCH operation.
   --  ------------------------------
   procedure Test_Http_Patch (T : in out Test) is
      Request : Client;
      Reply   : Response;
      Uri     : constant String := T.Get_Uri;
   begin
      Log.Info ("Patch on " & Uri);

      T.Server.Method := UNKNOWN;
      Request.Add_Header ("Content-Type", "application/x-www-form-urlencoded");
      Request.Set_Timeout (1.0);
      T.Assert (Request.Contains_Header ("Content-Type"), "Missing Content-Type");
      Request.Patch (Uri & "/patch", "patch-content", Reply);

      T.Assert (T.Server.Method = PATCH, "Invalid method received by server");
      Util.Tests.Assert_Equals (T, "application/x-www-form-urlencoded", T.Server.Content_Type,
                                "Invalid content type received by server");
      Util.Tests.Assert_Equals (T, 200, Reply.Get_Status, "Invalid status response");
      Util.Tests.Assert_Equals (T, "OK" & ASCII.CR & ASCII.LF, Reply.Get_Body, "Invalid response");

   end Test_Http_Patch;

   --  ------------------------------
   --  Test the http timeout.
   --  ------------------------------
   procedure Test_Http_Timeout (T : in out Test) is
      Request : Client;
      Reply   : Response;
      Uri     : constant String := T.Get_Uri;
   begin
      Log.Info ("Timeout on " & Uri);

      T.Server.Test_Timeout := True;
      T.Server.Method := UNKNOWN;
      Request.Set_Timeout (0.5);
      begin
         Request.Get (Uri & "/timeout", Reply);
         T.Fail ("No Connection_Error exception raised");

      exception
         when Connection_Error =>
            null;
      end;

   end Test_Http_Timeout;

end Util.Http.Clients.Tests;
