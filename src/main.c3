module lsp;
import std::io;
import std::core::log;
import std::thread;
import std::time;

fn int main(String[] args)
{
	log::set_priority_all(LogPriority.VERBOSE);
	log::info("STARTUP");
	io_handler::init();
	defer io_handler::quit();

	LspProject project;
	project.init(mem);
	defer project.free();

	log::info("Lsp initialized!");

	while LOOP: (true) @pool()
	{
		LspMessage? data = io_handler::read(tmem);
		if (catch err = data)
		{
			if (err == io_handler::NO_NEW_DATA)
			{
				thread::sleep(time::ms(1));
				continue;
			}

			log::error("Stream read error encountered: %s", err);
			continue;
		}
		
		switch (data.method)
		{
			case INITIALIZE:
				LspInitializeRequest init_req = initialize::parse_message(data)!!;
                io_handler::write(init_req.response(tmem));
			case DID_OPEN:
                LspDidOpenTextDocumentNotification text_opened = text_opened::parse_message(data)!!;
                project.open_file(text_opened.params.uri, text_opened.params.text);
            case DID_CLOSE:
                LspDidCloseTextDocumentNotification text_closed = text_closed::parse_message(data)!!;
                project.close_file(text_closed.params.uri);
			case SHUTDOWN:
				LspShutdownRequest shutdown = shutdown::parse_message(data)!!;
                io_handler::write(shutdown.response(tmem));
                log::info("Confirmed shutdown request. Awaiting exit notification...");
			case EXIT:
				log::info("Exit notification received. Terminating process.");
                break LOOP;
			default:
				log::verbose("Unhandled LSP method: %s", data.method);
				break;
		}
	};

	return 0;
}
