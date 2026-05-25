module lsp::msg_handler::publish_diag;

import dessert;
import derive;

import uri;

$expand(derive(MessageType::name, dessert));
constdef MessageType
{
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	LOG = 4,
	DEBUG = 5,
}

$expand(derive(LspDiagnostic::name, dessert));
struct LspDiagnostic 
{
	LspRange range;
}

fn void publish(Allocator allocator)
{
}
