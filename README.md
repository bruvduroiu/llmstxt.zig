# 📕 llmstxt.zig

AI-first approach to documentation, based on [llms.txt](https://llmstxt.org). Continouously rebuilds your `llms.txt` file to keep in sync with your codebase.


⚠️ This is a work in progress, expect many things to be broken.

## Build from source

- needs `zig@0.14.0`

```
git clone https://github.com/bruvduroiu/llmstxt.zig
cd llmstxt.zig/
zig build
```

## Usage

```
./zig-out/bin/llmstxt_zig file.ext
```

## Examples

<details>
    <summary>Python</summary>

    ```python
    from typing import Union

    from fastapi import FastAPI

    app = FastAPI()


    @app.get("/")
    def read_root():
        return {"Hello": "World"}


    @app.get("/items/{item_id}")
    def read_item(item_id: int, q: Union[str, None] = None):
        return {"item_id": item_id, "q": q}
    ```

    Result:

    ```
    File: test.py
    Language: python

    var app = FastAPI();
    func read_root() -> void;
    func read_item() -> void;
    ```

</details>

<details>
    <summary>Zig</summary>

    ```zig
    const std = @import("std");

    const root = @import("root.zig");
    const E = root.E;
    const P3 = root.P3;
    const Vec3 = root.Vec3;
    const Sphere = root.Sphere;
    const Ray = root.Ray;
    const Interval = root.Interval;

    pub const Hittable = union(enum) {
        const Self = @This();
        sphere: Sphere,

        pub fn initSphere(center: [3]E, radius: E) Self {
            return .{ .sphere = Sphere.init(center, radius) };
        }

        pub fn deinit(self: Self) void {
            switch (self) {
                inline else => |hittable| hittable.deinit(),
            }
        }

        pub const Collision = struct {
            const Inner = @This();
            pub const Face = enum { front, back };
            t: E,
            p: P3,
            normal: Vec3,
            face: Face,
        };

        pub fn collisionAt(self: Self, interval: Interval, ray: *const Ray) ?Collision {
            switch (self) {
                inline else => |hittable| return hittable.collisionAt(interval, ray),
            }
        }
    };
    ```

    Result:

    ```
    File: /Users/bogdanbuduroiu/development/bruvduroiu/raytracing.zig/src/hittable.zig
    Language: zig

    var t;
    var p;
    var normal;
    var face;
    ```

</details>

<details>
    <summary>Go</summary>

    ```go
    package batch_sliding_window

    import (
        "fmt"
        "go.temporal.io/sdk/temporal"
        "go.temporal.io/sdk/workflow"
        "time"
    )

    // ProcessBatchWorkflowInput input of the ProcessBatchWorkflow.
    // A single input structure is preferred to multiple workflow arguments to simplify backward compatible API changes.
    type ProcessBatchWorkflowInput struct {
        PageSize          int // Number of children started by a single sliding window workflow run
        SlidingWindowSize int // Maximum number of children to run in parallel.
        Partitions        int // How many sliding windows to run in parallel.
    }

    // ProcessBatchWorkflow sample Partitions the data set into continuous ranges.
    // A real application can choose any other way to divide the records into multiple collections.
    func ProcessBatchWorkflow(ctx workflow.Context, input ProcessBatchWorkflowInput) (processed int, err error) {
        ctx = workflow.WithActivityOptions(ctx, workflow.ActivityOptions{
            StartToCloseTimeout: 5 * time.Second,
        })

        var recordLoader *RecordLoader // RecordLoader activity reference
        var recordCount int
        err = workflow.ExecuteActivity(ctx, recordLoader.GetRecordCount).Get(ctx, &recordCount)
        if err != nil {
            return 0, err
        }

        if input.SlidingWindowSize < input.Partitions {
            return 0, temporal.NewApplicationError(
                "SlidingWindowSize cannot be less than number of partitions", "invalidInput")
        }
        partitions := divideIntoPartitions(recordCount, input.Partitions)
        windowSizes := divideIntoPartitions(input.SlidingWindowSize, input.Partitions)

        workflow.GetLogger(ctx).Info("ProcessBatchWorkflow",
            "input", input,
            "recordCount", recordCount,
            "partitions", partitions,
            "windowSizes", windowSizes)

        var results []workflow.ChildWorkflowFuture
        offset := 0
        for i := 0; i < input.Partitions; i++ {
            // Makes child id more user-friendly
            childId := fmt.Sprintf("%s/%d", workflow.GetInfo(ctx).WorkflowExecution.ID, i)
            childCtx := workflow.WithChildOptions(ctx, workflow.ChildWorkflowOptions{WorkflowID: childId})
            // Define partition boundaries.
            maximumPartitionOffset := offset + partitions[i]
            if maximumPartitionOffset > recordCount {
                maximumPartitionOffset = recordCount
            }
            input := SlidingWindowWorkflowInput{
                PageSize:          input.PageSize,
                SlidingWindowSize: windowSizes[i],
                Offset:            offset,                 // inclusive
                MaximumOffset:     maximumPartitionOffset, // exclusive
            }
            child := workflow.ExecuteChildWorkflow(childCtx, SlidingWindowWorkflow, input)
            results = append(results, child)
            offset += partitions[i]
        }
        // Waits for all child workflows to complete
        result := 0
        for _, partitionResult := range results {
            var r int
            err := partitionResult.Get(ctx, &r) // blocks until the child completion
            if err != nil {
                return 0, err
            }
            result += r
        }
        return result, nil
    }

    func divideIntoPartitions(number int, n int) []int {
        base := number / n
        remainder := number % n
        partitions := make([]int, n)

        for i := 0; i < n; i++ {
            partitions[i] = base
        }

        for i := 0; i < remainder; i++ {
            partitions[i] += 1
        }

        return partitions
    }
    ```

    Result:

    ```
    File: /Users/bogdanbuduroiu/development/temporalio/samples-go/batch-
    sliding-window/batch_workflow.go
    Language: go

    class ProcessBatchWorkflowInput {
    };
    var PageSize;
    var SlidingWindowSize;
    var Partitions;
    func ProcessBatchWorkflow() -> void;
    func divideIntoPartitions() -> void;
    ```
</details>
