use inc::Module::Install;

all_from 'lib/Twiterm.pm';

requires 'Proc::InvokeEditor';
requires 'Net::Twitter::Lite';
requires 'Term::Screen';
requires 'Date::Parse';
requires 'Log::Message';
requires 'Unicode::EastAsianWidth';
requires 'AnyEvent::Twitter';
requires 'Object::Event';

WriteAll();
