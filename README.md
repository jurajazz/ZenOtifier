# ZenOtifier
is simple to-do list notifier and reminder.

# Capabilities
* Remind recurrent events
* Graphical notification
* Simple snooze
* Transparent storing format in [YAML](https://en.wikipedia.org/wiki/YAML)
* Running graphically under Linux, OSX, Windows thanks to  [**Shoes**](http://shoesrb.com/) framework

# Installation
* Download and install [**Shoes**](http://shoesrb.com/downloads/)

# Starting
Start **Shoes** then open zenotifier.rb or run directly from command line:

    shoes zenotifier.rb

# Data
All data is stored at in the [HOME](https://en.wikipedia.org/wiki/Home_directory) under **.zenotifier** directory. Example: /home/user/.zenotifier

## Configuration
Configuration is stored in file *config.yaml*. It is designed to be self-explanatory. You can configure:
* Theme
* Colors
* Visibility of notify field
* Visibility of next event
* Time range where next event is evaluated

## Events
All planned events are stored in file *events.yaml*. It is designed to be self-explanatory.

# Enjoy
Do what you love.
Love what you do.

# Inspiration
Thanks to all inspiration projects:
* [mccal](https://github.com/lmcmicu/mccal.git) by Michael Cufarro
* [Quick To-Do Pro](http://www.capstralia.com/products/pro) smart software for task management

# Windows

Notification bubble on Windows requires [**Notifu**](https://www.paralint.com/projects/notifu) application to be installed and available in path. Then bubble will show for notification of events periodically.
