module lsp::server;
import lsp::io_handler;
import lsp::analysis;
import lsp::translator;
import lsp::msg_handler;

import std::io;
import std::core::log;
import std::thread;
import std::time;

bool running @local;
LspProject project;

fn void start(CliArgs args)
{
	log::set_priority_all(LogPriority.VERBOSE);
	log::info("STARTUP");
	io_handler::init();
	defer io_handler::quit();

	project.init(mem);
	defer project.free();

	log::info("Lsp initialized!");

	running = true;

	loop();
}

fn void loop()
{
	while (running) @pool()
	{
		LspMessage? data = io_handler::read(tmem);
		if (catch err = data)
		{
			if (err == io_handler::NO_NEW_DATA)
			{
				//TODO: How long?
				thread::sleep(time::ms(1));
				continue;
			}

			log::error("Stream read error encountered: %s", err);
			continue;
		}

		dispatch(&data);
	};
}

fn void dispatch(LspMessage* message)
{
	switch (message.method)
	{
		case INITIALIZE:
			initialize::response(tmem, message);
			break;
		case INITIALIZED:
			log::info("received Initialized");
			break;
		case DID_OPEN:
			project.open_file(message.params.did_open.document);
			break;
		case DID_CLOSE:
			project.close_file(message.params.did_close.document);
			break;
		case COMPLETION:
			completion::response(tmem, message);
			break;
		case SHUTDOWN:
			shutdown::response(tmem, message);
			break;
		case EXIT:
			log::info("Exit notification received. Terminating process.");
			running = false;
		default:
			log::verbose("Unhandled LSP method: %s", message.method);
			break;
	}
}