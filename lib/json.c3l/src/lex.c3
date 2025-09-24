module json::lex;

// Assumes correct json. Does not even check commas (just skips as whitespace)

import std::core::test;
import std::io;

enum Tag {
	NULL,
	TRUE,
	FALSE,
	STRING,
	NUM,
	ARRAY_START,
	ARRAY_END,
	OBJ_START,
	OBJ_END,
	FIELD_NAME,
}

// Currently non-streaming
struct Lexer {
	int curr;
	// currently just all input, no stream.
	String buffer;
	char[] token_slice;
}

fn void Lexer.init(&l, String input) {
	l.buffer = input;
}

// Skips commas :)
fn void Lexer.skip_whitespace(&l) {
	while LOOP: (true) {
		switch (l.buffer[l.curr]) {
			case ',':
			case ' ':
			case '\t':
			case '\r':
			case '\n':
				l.curr += 1;
			default: break LOOP;
		}
	}
}

fn Tag? Lexer.next(&l) {
	if (l.curr >= l.buffer.len) {
		return LEX_EOF?;
	}

	// forward whitespace
	l.skip_whitespace();

	// lex a token
	switch (l.buffer[l.curr]) {
		case 'n':
			if (l.buffer[l.curr:4] == "null") {
				l.token_slice = l.buffer[l.curr:4];
				l.curr += 4;
				return NULL;
			}
		case 't':
			if (l.buffer[l.curr:4] == "true") {
				l.token_slice = l.buffer[l.curr:4];
				l.curr += 4;
				return TRUE;
			}
		case 'f':
			if (l.buffer[l.curr:5] == "false") {
				l.token_slice = l.buffer[l.curr:5];
				l.curr += 5;
				return FALSE;
			}
		case '0'..'9':
			int len = 1;
			while LOOP: (true) {
				if (l.curr + len >= l.buffer.len) {
					break LOOP;
				}
				switch (l.buffer[l.curr + len]) {
					case '0'..'9':
						len += 1;
					default:
						break LOOP;
				}
			}
			l.token_slice = l.buffer[l.curr:len];
			l.curr += len;
			return NUM;
		case '[':
			l.token_slice = l.buffer[l.curr:1];
			l.curr += 1;
			return ARRAY_START;
		case ']':
			l.token_slice = l.buffer[l.curr:1];
			l.curr += 1;
			return ARRAY_END;
		case '{':
			l.token_slice = l.buffer[l.curr:1];
			l.curr += 1;
			return OBJ_START;
		case '}':
			l.token_slice = l.buffer[l.curr:1];
			l.curr += 1;
			return OBJ_END;
		// string or field name
		case '"':
			l.curr += 1;
			int len;
			while LOOP: (true) {
				switch (l.buffer[l.curr + len]) {
					case '"':
						break LOOP;
					default:
						len += 1;
				}
			}
			l.token_slice = l.buffer[l.curr:len];
			l.curr += len + 1;

			if (l.curr >= l.buffer.len) {
				return STRING;
			}
			l.skip_whitespace();
			if (l.buffer[l.curr] == ':') {
				l.curr += 1;
				return FIELD_NAME;
			} else {
				return STRING;
			}
		default:
			return LEX_MALFORMED?;
	}
	return LEX_MALFORMED?;
}

faultdef
	LEX_UNEXPECTED_IN_NUM,
	LEX_EOF,
	LEX_MALFORMED,
;

struct TestVector {
	String input;
	Tag[] expected_tags;
	String[] expected_slices;
}
