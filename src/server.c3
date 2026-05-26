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
	// log::set_logger(&&(NullLogger){});
	log::set_priority_all(LogPriority.INFO);
	log::info("STARTUP");
	io_handler::init();
	defer io_handler::quit();

	project.init(mem);
	defer project.free();

	log::info("Lsp initialized!");

	running = true;

	if (try path = args.stdlib_path.get())
	{
		process_stdlib(path);
	}

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
		case INITIALIZED:
			log::info("received Initialized");
		case DID_OPEN:
			project.open_file(message.params.did_open.document);
		case DID_CHANGE:
			project.change_file(message.params.did_change.document);
		case DID_CLOSE:
			project.close_file(message.params.did_close.document.uri);
		case COMPLETION:
			completion::response(tmem, &project, message);
		case SHUTDOWN:
			shutdown::response(tmem, message);
		case EXIT:
			log::info("Exit notification received. Terminating process.");
			running = false;
		default:
			log::verbose("Unhandled LSP method: %s", message.method);
	}
}

fn void process_stdlib(String std_path)
{
	Path path = path::tnew(std_path)!!;
	PathWalker walker = fn bool? (Path p, bool is_dir, void* data)
	{
		if (is_dir) return false;
		project.open_file({
			.uri = (DocumentUri)string::tformat("file://%s", p),
		}, true);
		return false;
	};
	path.walk(walker, null)!!;
}