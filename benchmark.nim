import times, algorithm

var a0 = newSeq[uint8](1000000000);
var a1 = newSeq[uint8](1000000000);
a0.fill(1);
a1.fill(1);

let t0 = cpuTime();
for i in countdown(a0.high, 0):
    a0.del(i);
let t1 = cpuTime();
for i in countdown(a1.high, 0):
    discard a1.pop();
let t2 = cpuTime();

echo "del: ", t1 - t0;
echo "pop: ", t2 - t1;