open MinCaml
open TLA

type backend =
  | Bytecode
  | PPBytecode

let backend_type = ref Bytecode

let print_import _ =
    print_endline "from rpython.jit.tl.threadedcode import tla\n"

let rec lexbuf oc l =
  let open TLA in
  Id.counter := 0;
  Typing.extenv := M.empty;
  Parser.exp Lexer.token l
  |> Typing.f
  |> KNormal.f
  |> Alpha.f
  |> Util.(iter !limit)
  |> Closure.f
  |> Virtual.f
  |> Simm.f
  |> function
  | p ->
    if !Config.flg_emit_virtual
    then (
      Asm.show_prog p |> prerr_string;
      prerr_newline ());
    (match !backend_type with
    | PPBytecode -> p |> Emit.f |> Bytecodes.pp_bytecode
    | Bytecode -> p |> Emit.f |> fun p ->
            print_import (); p |> Bytecodes.pp_tla_bytecode)
;;

let main f =
  let ic = open_in f in
  let oc = stdout in
  try
    let input = Lexing.from_channel ic in
    lexbuf oc input;
    close_in ic;
    close_out oc
  with
  | e ->
    close_in ic;
    close_out oc;
    raise e
;;

let () =
  let files = ref [] in
  Arg.parse
    [ ( "-inline"
      , Arg.Int (fun i -> MinCaml.Inline.threshold := i)
      , "set a threshold for inlining" )
    ; ( "-iter"
      , Arg.Int (fun i -> MinCaml.Util.limit := i)
      , "set a threshold for iterating" )
    ; ( "-pp"
      , Arg.Unit (fun _ -> backend_type := PPBytecode)
      , "emit bytecode for BacCaml" )
    ; ( "-virt"
      , Arg.Unit (fun _ -> Config.flg_emit_virtual := true)
      , "emit a MinCaml IR" )
    ; ( "-fr"
      , Arg.Unit (fun _ -> Config.flg_frame_reset := true)
      , "enable FRAME_RESET" )
    ; ( "-call-asm"
      , Arg.Unit (fun _ -> Config.flg_call_assembler := true)
      , "enable CALL_ASSEMBLER" )
    ]
    (fun s -> files := !files @ [ s ])
    (Sys.argv.(0) ^ " [-options] filename.ml");
  List.iter main !files
;;
