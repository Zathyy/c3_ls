module uri;

import std::io;
import std::core::ascii;

faultdef 
	INVALID_SYNTAX,
    UNSUPPORTED_SCHEME,
    MALFORMED_HEX;

struct Uri (Printable)
{
	String scheme;
	String path;
	Allocator allocator;
}

fn void Uri.free(&self)
{
	self.scheme.free(self.allocator);
	self.path.free(self.allocator);
}

fn sz? Uri.to_format(&self, Formatter* formatter) @dynamic
{
	return formatter.printf("%s://%s", self.scheme, self.path);
}

fn bool Uri.equal(self, Uri other) @operator(==)
{
	return self.scheme == other.scheme
		&& self.path == other.path;
}

<*
	Right now only supports file schema
	example: file://home/user/code/main.c3
	@return? INVALID_SYNTAX, UNSUPPORTED_SCHEME, MALFORMED_HEX
*>
fn Uri? parse(Allocator allocator, String raw_uri) => @pool()
{
	// Isolate the scheme separator '://'
	sz scheme_bound = raw_uri.index_of("://")!;
	if (scheme_bound == sz::max || scheme_bound == 0)
	{
		return INVALID_SYNTAX~;
	}

	String scheme = raw_uri[:scheme_bound];
	if (scheme != "file")
	{
		log::error("unhandleable URI scheme: %s", scheme);
		return UNSUPPORTED_SCHEME~;
	}

	// Advance past "://"
	String remaining_path = raw_uri[scheme_bound + 3..];

	// strip all leading slashes
	while (remaining_path.starts_with("/"))
    {
        remaining_path = remaining_path[1..];
    }

	// Adjust for Windows authority/drive formatting quirks
	// Example: '/C%3A/foo' -> first slash is authority spacer, drop it so we get 'C%3A/foo'
	$if env::WIN32:
		if (remaining_path.starts_with("/") && remaining_path.len >= 4 && remaining_path[2] == '%' && remaining_path[3] == '3')
		{
			remaining_path = remaining_path[1..];
		}
	$endif

	// Decode percent-encoded text characters in-place
	char[] decoded = alloc::new_array(tmem, char, remaining_path.len);
	sz write_idx = 0;

	for (sz i = 0; i < remaining_path.len; )
	{
		if (remaining_path[i] == '%' && i + 2 < remaining_path.len)
		{
			char h1 = remaining_path[i + 1];
			char h2 = remaining_path[i + 2];

			if (!h1.is_xdigit() || !h2.is_xdigit())
			{
				return MALFORMED_HEX~;
			}

			decoded[write_idx++] = (char)((char.from_hex(h1) << 4) | char.from_hex(h2));
			i += 3;
		}
		else if (remaining_path[i] == '\\')
		{
			decoded[write_idx++] = '/'; 
			i++;
		}
		else
		{
			decoded[write_idx++] = remaining_path[i];
			i++;
		}
	}

	String native_path = (String)decoded[:write_idx];

	// Clean up Windows casing anomalies (c: -> C:)
	$if env::WIN32:
		if (native_path.len >= 2 && native_path[0].is_lower() && native_path[1] == ':')
        {
            native_path[0] = native_path[0].to_upper(); 
        }
	$endif

	return (Uri){
		.scheme = scheme.copy(allocator),
		.path = native_path.copy(allocator),
		.allocator = allocator
	};
}

fn void uri_windows_test() @test
{
    String value = `file:///C%3A/project/readme.md`;
    Uri expected = { 
        .scheme = "file",
        .path = "C:/project/readme.md",
    };

    Uri uri = parse(mem, value)!!;
    defer uri.free();
    log::debug("Windows Test Result: %s", uri);

    assert(uri == expected);
}

fn void uri_linux_test() @test
{
    String value = `file:///home/user/code/main.c3`;
    
    Uri expected = { 
        .scheme = "file",
        .path = "home/user/code/main.c3", 
    };

    Uri uri = parse(mem, value)!!;
    defer uri.free();
    log::debug("Linux Test Result: %s", uri);

    assert(uri == expected);
}