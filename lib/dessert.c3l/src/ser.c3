module dessert::ser;
import dessert::utils;

import std::io;
import std::core::types;
import std::collections::maybe;

interface Serializer {
  fn void? struct_start(String name);
  fn void? serialize_field_start(String name, FieldAttrs fmt);
  fn void? serialize_field_end(String name, FieldAttrs fmt);
  fn void? struct_end(String name);

  fn void? serialize_slice_start(ulong len);
  fn void? serialize_slice_end(ulong len);

  fn void? serialize_null();
  fn void? serialize_bool(bool b);
  fn void? serialize_long(long l);
  fn void? serialize_string(String s);
  fn void? serialize_double(double d);

  fn void? serialize_char(char c) @optional;
  fn void? serialize_ichar(ichar c) @optional;

  fn void? serialize_short(short s) @optional;
  fn void? serialize_int(int i) @optional;
  fn void? serialize_int128(int128 i) @optional;

  fn void? serialize_uint(uint i) @optional;
  fn void? serialize_ushort(ushort s) @optional;
  fn void? serialize_ulong(ulong l) @optional;
  fn void? serialize_uint128(uint128 i) @optional;

  fn void? serialize_zstring(ZString s) @optional;

  fn void? serialize_float(float f) @optional;
  // fn void? serialize_float16(float16 f) @optional @if($defined(float16));
  // fn void? serialize_float128(float128 f) @optional @if($defined(float128));
}

faultdef VALIDATOR_ERROR;

// Should be treated as a protocol, don't derive it directly
interface Serializable {
  fn void? serialize(Serializer serializer);
}

<* @require $defined(Serializer s = serializer) *>
macro serialize(serializer, value) {
  serialize_value(serializer, value, {})!;
  return serializer.result();
}

/*
  attributes:
  - rename
  - skip
  - skip_if_empty
  - aliases
  - default
  - validator
*/

macro impl_serialize(s, Serializer serializer) {
  $if $typeof(s).kindof != POINTER:
    $error "The first parameter must be a &self pointer.";
  $endif

  $switch:
    $case $typeof(s).inner.kindof == ENUM:
      impl_serialize_enum(s, serializer)!;

    $case $typeof(s).inner.kindof == STRUCT:
      serializer.struct_start($typeof(s).inner.nameof)!;
      $foreach $member : $typeof(s).inner.membersof:
        DessertFieldConfig $dessert = $member.has_tagof("dessert:ser") ??? $member.tagof("dessert:ser") : (DessertFieldConfig) {};
        $if !$dessert.skip:
          $if $dessert.validator.len > 0: 
            if (!s.$eval($dessert.validator)(s.$eval($member.nameof))) {
              return VALIDATOR_ERROR~;
            }
          $endif

          $switch:
            $case $dessert.skip_if_empty:
              if (!@is_empty(s.$eval($member.nameof))) {
                serializer.serialize_field_start(
                  $dessert.rename.len > 0 ??? $dessert.rename : $member.nameof,
                  $dessert.fmt,
                )!;
                serialize_value(serializer, s.$eval($member.nameof), $dessert)!;
                serializer.serialize_field_end(
                  $dessert.rename.len > 0 ??? $dessert.rename : $member.nameof,
                  $dessert.fmt,
                )!;
              }

            $case $defined(s.$eval("skip_serializing_" +++ $member.nameof)()) 
              &&& $typeof(s.$eval("skip_serializing_" +++ $member.nameof)).returns == bool:

              if (!s.$eval("skip_serializing_" +++ $member.nameof)()) {
                serializer.serialize_field_start(
                  $dessert.rename.len > 0 ??? $dessert.rename : $member.nameof,
                  $dessert.fmt,
                )!;
                serialize_value(serializer, s.$eval($member.nameof), $dessert)!;
                serializer.serialize_field_end(
                  $dessert.rename.len > 0 ??? $dessert.rename : $member.nameof,
                  $dessert.fmt,
                )!;
              }

            $default:
              serializer.serialize_field_start(
                $dessert.rename.len > 0 ??? $dessert.rename : $member.nameof,
                $dessert.fmt,
              )!;
              serialize_value(serializer, s.$eval($member.nameof), $dessert)!;
              serializer.serialize_field_end(
                $dessert.rename.len > 0 ??? $dessert.rename : $member.nameof,
                $dessert.fmt,
              )!;
          $endswitch
        $endif
      $endforeach
      serializer.struct_end($typeof(s).inner.nameof)!;
  $endswitch
}

macro @is_empty(#value) {
  $switch:
    $case $defined(#value.len) &&& $defined(#value[0]):
      return #value.len == 0;
    $case utils::@is_maybe_expr(#value):
      var inner = #value.get();
      if (catch inner) {
        return true;
      } else {
        return false;
      }
    $case $typeof(#value).kindof == POINTER:
      return #value == null;
  $endswitch
}

macro serialize_value(serializer, value, $config) {
  $switch:
    $case $defined(value.serialize) &&& $defined(value.serialize(serializer)):
      $if $typeof(value).kindof == POINTER:
       if (value == null) {
         serializer.serialize_null()!;
         return;
       }
      $endif
      value.serialize(serializer)!;

    $case utils::@is_maybe_expr(value):
      var inner = value.get();
      if (catch inner) {
        serializer.serialize_null()!;
      } else {
        inner.serialize(serializer)!;
      }

    $case $defined(value.len) &&& $defined(value[0]) &&& $defined(value.len()):
      serializer.serialize_slice_start(value.len())!;
      foreach (el: value) {
        serialize_value(serializer, value, $config)!;
      }
      serializer.serialize_slice_end(value.len())!;

    $case $defined(value.len) &&& $defined(value[0]):
      serializer.serialize_slice_start(value.len)!;
      foreach (el: value) {
        serialize_value(serializer, el, $config)!;
      }
      serializer.serialize_slice_end(value.len)!;

    $default:
      $error @sprintf("Value not serializable: '%s (%s)'", $typeof(value).nameof, $typeof(value).kindof);
  $endswitch
}

<*
  @require $typeof(s).inner.kindof == ENUM
*>
macro impl_serialize_enum(s, serializer) @local {
  var $type = $typeof(s).inner;
  var $config = $type.has_tagof("dessert:ser:enum") ??? $type.tagof("dessert:ser:enum") : (DessertEnumConfig) {};

  $switch $config.as:
    $case NAME:
      return serialize_value(serializer, s.nameof, {});

    $case ORDINAL:
      return serialize_value(serializer, s.ordinal, {});

    $case FIELD:
      var $field_name = $config.field;
      $if $field_name.len == 0:
        $error "While serializing an enum: When the 'as' attribute is set to 'FIELD', 'field' must be provided with the name of an associated field of the enum.";
      $endif
      return serialize_value(serializer, s.$eval($field_name), {});
  $endswitch
}

macro @is_serializable(#value) {
  return $defined(#value.serialize) ||| ($defined(#value.len) &&& $defined(#value[0])) ||| 
    utils::@is_maybe_expr(#value);
}

