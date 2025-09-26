module lsp;
import std::io;
import std::core::log;

fn int main(String[] args)
{
	log::set_priority_all(LogPriority.VERBOSE);
	log::info("STARTUP");
	io_handler::init();
	defer io_handler::quit();
	while (true) @pool()
	{
		LspMessage? data = io_handler::read(tmem);
		if (catch excuse = data) continue;
		(void)msg_handler::handle_message(data);
	};
	log::info("BYE!!!!");
	return 0;
}
