module example @if($feature(DESSERT_EXAMPLE));
import std;
import dessert;
import json;
import derive;
import std::collections::object;

$expand(derive(Animal::name, dessert));
struct Animal {
  String name;
  String specie;
}

struct Person {
  int age;
  String name;
  Animal[] pets;
  int x;
  union @DField({ .tagged = { .by = "x" } }) {
    int foo;
    double bar;
  }
  Maybe{Person*} friend @DField({ .rename = "my_friend" });
  bool is_cool @DField({ .skip = true });
}

// fn void? Person.serialize(&self, Serializer serializer) => 
//   ser::impl_serialize(self, serializer);

// fn void? Person.deserialize(&self, Deserializer deserializer) =>
//   des::impl_deserialize(self, deserializer);


// fn int main(String[] args) {
//   Animal sharpie = { .name = "Sharpie", .specie = "Cat" };
//   Person connor = { .age = 20, .name = "Connor", .is_cool = true, .x = 1, .bar = 0.2 };
//   connor.pets = { sharpie };
//
//   JsonSerializer s = json::serializer();
//   JsonValue? json = ser::serialize(&s, connor);
//   if (catch json) {
//     io::printn("Error serializing");
//     return -1;
//   }
//   
//   json.print()!!;
//   io::printn();
//   
//   // Person? p = des::deserialize{Person}(&&json::deserializer(json.to_string()));
//   // if (catch p) {
//   //   io::printn("Error deserializing");
//   //   return -1;
//   // }
//   //
//   // io::printfn("Person named %s with a %s named %s", p.name, p.pets[0].specie, p.pets[0].name);
//   
//   return 0;
// }

// $expand(derive(Response::name, dessert::serialize));
// struct Response {
//   int kind;
//   union params @DField({ .tagged_by = "kind" }) {
//     int first;
//     double second;
//     String third;
//   }
// }

union MyUnion {
  int first;
  struct second {
    int x;
  }
  // String third;
}

$expand(derive(Foo::name, dessert));
struct Foo {
  int bar;
}

$expand(derive(Bar::name, dessert));
enum Bar : (String name) {
  FIRST { "first" },
  SECOND { "second" },
  THIRD { "third" },
}

$expand(derive(Request::name, dessert));
struct Request {
  Bar kind;
  MyUnion p @DField({ .tagged = { .by = "kind", .inlined = true, .match.by = DESCRIPTION, .unmapped.as = EMPTY_STRUCT } });
}

$expand(derive(Format::name, dessert));
enum Format : (String mime) {
  JSON_FMT { "json_fmt" },
  CSV_FMT  { "csv_fmt"  },
}

$expand(derive(Output::name, dessert));
struct Output {
  Format kind;
  union payload @DField({ .tagged = { .by = "kind", .inlined = true, .match = { .by = FIELD, .field = "mime" } } }) {
    int    json_fmt;  // matched when kind.mime == "json_fmt"
    String csv_fmt;   // matched when kind.mime == "csv_fmt"
  }
}
fn void main() {
  // Request req = { .kind = THIRD, .p = {.second = { .x = 2 }} };
  // String s = ser::serialize(&&json::string_serializer(), req)!!;
  // io::printn(s);
  //
  // // Request p = des::deserialize{Request}(&&json::deserializer(s))!!;
  // Request p = des::deserialize{Request}(&&json::deserializer(`{"kind":"THIRD","p":{"x":2}}`))!!;
  // io::printn("DESERIALIZED:");
  // io::printn(p.kind);
  // io::printn(p.p.first);

  Output o = { .kind = JSON_FMT, .payload.json_fmt = 12 };
  String s = ser::serialize(&&json::string_serializer(), o)!!;
  io::printn(s);

  Output p = des::deserialize{Output}(&&json::deserializer(s))!!;
  io::printn(string::from_struct(tmem, p));
  io::printn(p.payload.json_fmt);

  // Request req2 = { .kind = 2, .third = "Wow" };
  // s = ser::serialize(&&json::string_serializer(), req2)!!;
  // io::printn(s);
  //
  // Response res = { .kind = 2, .params = { .third = "Wow" }};
  // s = ser::serialize(&&json::string_serializer(), res)!!;
  // io::printn(s);
}
