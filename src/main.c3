module lsp;
import lsp::server;
import seali;

fn int main(String[] args)
{
	server::start(args);
	return 0;
}
