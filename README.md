# LakeTemp

Live water temperature and wind for **Lake Garda**, on the iPhone home screen.

## Why

Swimmers, sailors and windsurfers on Lake Garda check two things before going out: how cold the water is and how strong the wind is. That data exists, but it is buried in websites that are slow to open on a phone. LakeTemp puts it on one screen and in a widget you can read without opening anything.

## What it does

- **Current water temperature** with the time of the last measurement.
- **Wind** speed, gusts and the matching Beaufort level.
- **History chart** to see the trend over different time ranges.
- **Two home-screen widgets:** temperature and wind.

## How it works

The app is the front end of a small data pipeline I built:

1. A **Cloudflare Worker on a cron schedule** collects the measurements and stores them in **Cloudflare D1** (SQLite).
2. The same Worker exposes a tiny REST API (`/`, `/wind`, `/past_data/{range}`). Web requests only read from the database; collection happens exclusively on the schedule.
3. The SwiftUI app and WidgetKit widgets read from that API.

## Stack

SwiftUI · WidgetKit · Swift Charts · Cloudflare Workers · Cloudflare D1
