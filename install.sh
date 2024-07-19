#!/bin/bash

#Installing:
echo "Installing XSpear"
gem install XSpear
echo "XSpear Successfully Installed"
# Other libraries
echo "Installing libraries"
gem install colorize && gem install selenium-webdriver && gem install terminal-table && gem install progress_bar

echo "Yooh! Installed uccessfully!"
echo "Now you can use this Bash script"
echo "For usage: ./xspear.sh domains.txt"
