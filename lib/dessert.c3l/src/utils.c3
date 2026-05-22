module dessert::utils;

const char[256] TO_UPPER @private = { ['a'..'z'] = 'a' - 'A' };
macro char @to_upper(char $c) => $c - TO_UPPER[$c];

macro @is_maybe($value) {
  return ($defined($value.get) &&& $defined($value.get()) &&& 
          ($defined($value.get()!) ||| $defined($value == maybe::value{$typeof($value.value)}($value.value))));
}

macro @is_maybe_expr(#value) {
  return ($defined(#value.get) &&& $defined(#value.get()) &&& 
          ($defined(#value.get()!) ||| $defined(#value == maybe::value{$typeof(#value.value)}(#value.value))));
}

macro @is_maybe_type($Type) {
  $Type $value;
  return ($defined($value.get) &&& $defined($value.get()) &&& 
          ($defined($value.get()!) ||| $defined($value == maybe::value{$typeof($value.value)}($value.value))));
}

macro @get_maybe_inner_type($Type) {
  $if @is_maybe_type($Type):
    $Type $t;
    return @get_maybe_inner_type($typeof($t.value));
  $endif
  return $Type;
}


macro @get_tag($Type, String $tag_name, $default_val) @const @builtin => $Type::has_tag($tag_name) ??? $Type::get_tag($tag_name) : $default_val;

macro @rename(DFieldConfig $config, String $name, DStructConfig $struct_config) @const {
  $if $config.rename.len > 0:
    return $config.rename;
  $else
    $switch $struct_config.rename_all:
      $case VERBATIM:
        return $name;

      $case CAMEL_CASE:
        String $new_name = "";
        $for int $i = 0; $i < $name.len; $i++:
          $if $name[$i] == '_':
            $new_name +++= @to_upper($name[$i+1]);
            $i++;
          $else
            $new_name +++= $name[$i];
          $endif
        $endfor
        return $new_name;

      $default:
        $error @sprintf("CaseConvention %s not supported for now.");
    $endswitch
  $endif
}

