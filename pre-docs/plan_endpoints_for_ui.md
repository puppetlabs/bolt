## Endpoint Definition to Display Plans in UI

The purpose of this work is to power display plan jobs in the console orchestrator needs `plan_job` endpoints that allow plan details to be retrieved. There are 2 main tasks for this:

### Add events to the /plan_jobs/:id/events stream  

* Add a plan_jobs endpoint route (is route the right word?)
* Add a new database table for plan_job events
* Add plan_finish and plan_task_finish events to the plan_jobs event stream with the following formats:

#### plan_task finish 
```
{
  id: "unique event ID",
  type: plan_task_finish
  timestamp: "2016-05-05T19:50:08Z",
  details: { 
    "name" : "stringified plan ID",
    "id" : "url reference to jobs endpoint" 
  },
}
```

#### plan_finish
```
{
  id: "unique event ID"
  type: plan_job_finish
  timestamp: "2016-05-05T19:50:08Z",
  details: { 
    "name" : "stringified plan ID",
    "id" : "url reference to jobs endpoint"
  },
}
```
 
### Add /plan_job/:id endpoint

This endpoint retrieves details about the specified plan job.  It should behave similarly to the [job/:id endpoint](https://puppet.com/docs/pe/latest/orchestrator/orchestrator_api_jobs_endpoint.html#ariaid-title3) , and does not accept parameters.

#### Response

```
{
  "id" : "The plan job 'name' or id",
  "state": "finished",
  "options": {
    "description" : "This is a plan run",
    "plan_name" : "package::install",
    "parameters" : { "foo" : "bar" },
  }
  "timestamp": "2016-05-20T16:45:31Z",
  "output" : {} # TODO do we need this?
  "status" : [ {
      "state" : "running",
      "enter_time" : "2016-04-11T18:44:31Z",
      "exit_time" : "2016-04-11T18:45:31Z"
  }, {
      "state" : "finished",
      "enter_time" : "2016-04-11T18:45:31Z",
      "exit_time" : null
  }]
  "owner" : {
      "id" : "751a8f7e-b53a-4ccd-9f4f-e93db6aa38ec",
      "login" : "brian"
  },
  "events" : {
         "id" : "https://localhost:8143/orchestrator/v1/plan_jobs/1234/events"
  },
}
```