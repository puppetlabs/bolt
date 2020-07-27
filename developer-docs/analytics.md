# Bolt analytics

Bolt submits requests to Google Analytics when run, unless analytics are disabled. 

## Submitting analytics requests

Use the `Bolt::Analytics::Client` instance to submit analytics requests. There
should only be one instance of this class that is passed around for the
lifecycle of the application. Do not create a new instance for your code.

The client will make a request with a specific tracking id embedded in the
code. That is the Google Analytics project the data will be associated with.

We only use two kinds of requests: `event` and `screen_view`.

### Events

An event is the simplest request in GA. It represents that _something_ happened
and is defined by a `category` and an `action`. It may optionally have a
`label` and a `value`. As a general rule, do not use `value` as GA doesn't
provide useful mechanisms to process it.

For example: `Plan, call_function, run_task`. This event has a category, an
action and a label. The category tells us that this was some type of Plan
event, the action tells us what the event was, and the label tells us more
detail about what happened.

Almost all data we collect is in the form of events.

### Screen views

We use screen view requests to indicate when a Bolt CLI command is run. We
automatically include a number of custom dimensions describing the environment,
like what kind of project directory is being used, how many nodes and groups
are in the inventory, etc.

There shouldn't generally be a need to add new screen view requests.

### Custom dimensions

Events and screen views can include custom dimensions to collect arbitrary
additional data associated with the request. These fields *must* be defined in
Google Analytics in order to be collected. In the API, the dimensions are named
`cd1`, `cd2`, etc, with `cd` meaning "custom dimension". We automatically
include `cd1` (operating system) with every request.

Add new custom dimensions from the admin section of GA under the Bolt
"Property". The index of the custom dimension must match the key used in code.

We generally use the event action and label to specify _what_ happened and
custom dimensions to annotate _how_ it happened.

## Testing new analytics

Requests to Google Analytics always return a success code, even if the data is
invalid. Therefore, simply testing that the request succeeded is not sufficient
to verify that the new analytics are working.

We have a "Bolt Development" project in Google Analytics to use for testing.
Change the tracking id in `analytics.rb` from `[...]-1` to `[...]-2` and your
data will be sent to the development project. Testing against the development
project helps us avoid polluting a new custom dimension before the
implementation is finalized. It also skirts the fact that the main Bolt project
automatically filters out any data sent from a Puppet IP address.

Bolt's `Gemfile` automatically sets `BOLT_DISABLE_ANALYTICS` so that analytics
won't be sent. To work around that, you can either remove that line of code or
create a `Gemfile.local` (which will be loaded automatically) containing:

```rb
ENV.delete('BOLT_DISABLE_ANALYTICS')
```

That will undo the ENV var and allow analytics to be sent.

Run Bolt a few times to submit data, and check the "Realtime" tab in the GA
console to ensure your requests are being received. 

You should then use Data Studio to create a chart demonstrating that the new
analytics can actually be used to answer the question they are intended to
answer. You'll need to _wait_ for data to appear. Requests are processed
asynchronously by GA and it can take a while for it to appear in Data Studio,
especially if you've added new custom dimensions.

Modeling the data in Data Studio before merging the change helps ensure that
the data is being collected in a form that suits the problem it's meant to solve.
