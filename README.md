SynologyDownloader
==================

This is a RSS-downloader written in ruby, it takes a list of RSS-feeds and sends the torrent-link in the rss to a Synology Downloadstation to be downloaded. the RSS-downloader also saves a local database with which items that has been successfully added to the download-queue of the Downloadstation.

Tested with ruby version: 1.9.3p484

# Installation
http://devnore.github.io/SynologyDownloader/

1. Set it up.

	```
	git clone https://github.com/devnore/SynologyDownloader.git
	cd SynologyDownloader
	bundle install
	mkdir ~/.SynologyDownloader
	cp settings_default.yml ~/.SynologyDownloader/settings.yml
	```	
2. Edit ~/.SynologyDownloader/settings.yml with your info.


# Configuration

Add RSS-feeds with torrents to your settings.yml-file to download them. The script will create a yml-file with information on already downloaded torrents (Sent to be downloaded).

Prefix the name of the RSS with PIRATE- to take the title of the rss-entry and search for it on Piratebay.


# Usage
Run the app.

# Disclamer
Bugs and feature-requests are welcome, but don't expect to much as I'm only doing this app as part of learing Ruby.
