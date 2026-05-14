module dessert::format::xml;
import dessert::ser;
import dessert::des;
import std::collections::list;

faultdef XML_ATTRIBUTE_AFTER_FIELD, XML_SLICE_IN_ATTRIBUTE;

struct XMLSerializer (Serializer) {
  DString output;
  List{String} current_field;
  bool attribute_mode;
}

fn XMLSerializer serializer() {
  return {};
}

fn void? XMLSerializer.serialize_null(&self) @dynamic {
  self.output.append("null");
}

fn void? XMLSerializer.serialize_bool(&self, bool b) @dynamic {
  self.output.append(b ? "true" : "false");
}

fn void? XMLSerializer.serialize_long(&self, long i) @dynamic {
  self.output.append(string::tformat("%s", i));
}

fn void? XMLSerializer.serialize_double(&self, double f) @dynamic {
  self.output.append(string::tformat("%s", f));
}

fn void? XMLSerializer.serialize_string(&self, String s) @dynamic {
  self.output.append(s);
}

fn void? XMLSerializer.struct_start(&self, String name) @dynamic {
  self.output.append("<");
  self.output.append(name.to_lower_copy(tmem));
  self.attribute_mode = true;
}

fn void? XMLSerializer.struct_end(&self, String name) @dynamic {
  self.output.append("</");
  self.output.append(name.to_lower_copy(tmem));
  self.output.append(">");
}

fn void? XMLSerializer.serialize_slice_start(&self, ulong len) @dynamic {
  if (self.attribute_mode) {
    return XML_SLICE_IN_ATTRIBUTE~;
  }

  String name = self.current_field[^1] ?: "el";
  if (name.ends_with("s")) {
    name = name[..^2];
  }
  self.output.append("<");
  self.output.append(name);
  self.output.append(">");
}
fn void? XMLSerializer.serialize_slice_end(&self, ulong len) @dynamic {
  String name = self.current_field[^1] ?: "el";
  if (name.ends_with("s")) {
    name = name[..^2];
  }
  self.output.append("</");
  self.output.append(name);
  self.output.append(">");
}

<* 
  Fields that start with @ will be serialized as attributes
*>
fn void? XMLSerializer.serialize_field_start(&self, String name, FieldAttrs fmt) @dynamic {
  if (try attr = fmt.get("xml:attribute") && attr == "true") {
    if (self.attribute_mode) {
      self.output.append(" ");
      self.output.append(name);
      self.output.append("=\"");
      return;
    } else {
      return XML_ATTRIBUTE_AFTER_FIELD~;
    }
  }

  if (self.attribute_mode) {
    self.output.append(">");
    self.attribute_mode = false;
  }
  self.output.append("<");
  self.output.append(name);
  self.output.append(">");
  self.current_field.push(name);
}

fn void? XMLSerializer.serialize_field_end(&self, String name, FieldAttrs fmt) @dynamic {
  if (self.attribute_mode) {
    self.output.append("\"");
  } else {
    self.output.append("</");
    self.output.append(name);
    self.output.append(">");
    (void)self.current_field.pop();
  }
}

fn String XMLSerializer.result(&self) => self.output.str_view();

// struct XMLDeserializer (Deserializer) {
//   InStream source;
// }
