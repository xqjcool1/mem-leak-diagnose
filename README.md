# mem-leak-diagnose
memory leak diagnose shell scripts
This script is used to help locate memory leaks on linux platforms.

USAGE：Run the shell script directly and it will return the diagnose result.

1. please check these proesses(listed below)
2. tmp directory occupies too much memory
3. slab memory is suspicious, please check
4. vmalloc memory is suspicious, please check
5. HugePage consumption
6. black hole memory
6.1 Virtual machine memory is occupied by the host
6.2 Packets queued in socket Recv-Q and Send-Q occupy too much memory

https://blog.csdn.net/xqjcool/article/details/105151549

MEM_THRESHOLD: memory leak threshold. We will start the analysis when the memory usage is greater than the threshold.
