open Core
open Expect_test_helpers_core
open! Int.Replace_polymorphic_compare

(** Ensure that applicatives actually match the signature needed. *)
module Restrict_F (F : Applicative.S) : sig
  module F : Record_builder.Partial_applicative_S
end = struct
  module F = F
end

module Restrict_F2 (F : Applicative.S2) : sig
  module F : Record_builder.Partial_applicative_S2
end = struct
  module F = F
end

module R = struct
  type t =
    { one : string
    ; two : string
    ; three : Date.t
    ; four : int
    }
  [@@deriving sexp_of, fields ~iterators:make_creator, compare]

  let examples =
    let open List.Let_syntax in
    let str = [ "hello"; "world"; "tree"; "cloud"; "sea" ]
    and date =
      let%map year = [ 2001; 2020 ]
      and day = [ 01; 05; 11 ]
      and month = [ Month.Apr; Month.Aug ] in
      Date.create_exn ~y:year ~m:month ~d:day
    and int = [ 5; 10; 11; 42 ] in
    let%map one = str
    and two = str
    and three = date
    and four = int in
    { one; two; three; four }
  ;;
end

let%test_unit "record_builder test" =
  let module B =
    Record_builder.Make_2 (struct
      type (+'a, -'b) t = 'b -> 'a

      let map x ~f = Fn.compose f x

      let both l r x =
        let l' = l x in
        l', r x
      ;;
    end)
  in
  let fields_seen = ref 0 in
  let handle_field field =
    B.field
      (fun record ->
        incr fields_seen;
        Field.get field record)
      field
  in
  let equivalent_to_id =
    B.build_for_record
      (R.Fields.make_creator
         ~one:handle_field
         ~two:handle_field
         ~three:handle_field
         ~four:handle_field)
  in
  List.iter R.examples ~f:(fun record ->
    [%test_result: R.t] ~expect:record (equivalent_to_id record));
  assert (!fields_seen > 0)
;;

let%expect_test "order of effects" =
  let module F = struct
    type 'a t = { run : unit -> unit } [@@unboxed] [@@deriving fields ~getters]

    let map x ~f:_ = { run = run x }

    let both x y =
      { run =
          (fun () ->
            run x ();
            run y ())
      }
    ;;

    let print_message msg = { run = (fun () -> print_string msg) }
  end
  in
  let module B = Record_builder.Make (F) in
  let print_field_names =
    let handle_field field =
      B.field (F.print_message (sprintf "field: %s\n" (Field.name field))) field
    in
    B.build_for_record
      (R.Fields.make_creator
         ~one:handle_field
         ~two:handle_field
         ~three:handle_field
         ~four:handle_field)
  in
  F.run print_field_names ();
  [%expect
    {|
    field: one
    field: two
    field: three
    field: four
    |}]
;;
