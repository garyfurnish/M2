#ifndef _system_supervisor_h_
#define _system_supervisor_h_
#include <cgc1/cgc1.hpp>
/* this next bit is copied from ../d/atomic.d, but it should be include, instead */

#include <atomic_ops.h>
#ifndef atomic_field_decl
#define atomic_field_decl
struct atomic_field {
  AO_t field;
};

#define load_Field(x) AO_load(&(x).field)
#define test_Field(x) (load_Field(x) != 0)
#define store_Field(x, val) AO_store(&(x).field, val)
#endif
#include "mutexclass.hpp"
#include <M2/gc-include.h>
#include <list>
#include <map>
#include <set>

typedef struct parse_ThreadCellBody_struct *parse_ThreadCellBody;

typedef void *(*ThreadTaskFunctionPtr)(void *);
class supervisor_thread_t;
// not garbage collected
struct ThreadTask {
  ThreadTask(
      const char *name, ThreadTaskFunctionPtr func, void *userData, bool timeLimit, time_t timeLimitSeconds, bool isM2Task);
  ~ThreadTask();
  /// Name of task -- NULL for not used.
  const char *m_Name;
  /// function to call
  ThreadTaskFunctionPtr m_Func;
  /// data to pass into function
  void *m_UserData;
  /// result of task
  void *m_Result;
  /// Is this a task from the M2 interperter
  bool m_IsM2Task;
  /// is the task done
  bool m_Done;
  /// has the task started
  bool m_Started;
  /// Should the task keep running
  bool m_KeepRunning;
  /// Is the task ready to run (queued, no deps, etc)
  bool m_ReadyToRun;
  /// Is the task currently running
  bool m_Running;
  /// tasks to cancel upon completion
  std::set<ThreadTask *, ::std::less<>, ::cgc1::gc_allocator_t<ThreadTask *>> m_CancelTasks;
  /// tasks to start upon completion
  std::set<ThreadTask *, ::std::less<>, ::cgc1::gc_allocator_t<ThreadTask *>> m_StartTasks;
  /// Is there a time limit for this task
  bool m_TimeLimit;
  /// Time limit in seconds for this task.
  time_t m_Seconds;
  /// Dependencies that must be satisfied in order to start
  std::set<ThreadTask *, ::std::less<>, ::cgc1::gc_allocator_t<ThreadTask *>> m_Dependencies;
  /// Dependencies that have been finished
  std::set<ThreadTask *, ::std::less<>, ::cgc1::gc_allocator_t<ThreadTask *>> m_FinishedDependencies;
  /// Mutex for accessing task
  pthreadMutex m_Mutex;
  /// run task
  void run(supervisor_thread_t *thread);
  /// Condition variable for task
  pthread_cond_t m_FinishCondition;
  /// Current thread running on
  supervisor_thread_t *m_CurrentThread;
  void *waitOn();
};

// not garbage collected
struct ThreadSupervisorInformation {
  /// Id for thread
  pthread_t m_ThreadId;
  /// body for the thread (remember this is a pointer)
  parse_ThreadCellBody m_Body;
  /// Currently running task
  struct ThreadTask *m_Task;
};

class supervisor_thread_t
{
public:
  supervisor_thread_t(int localThreadId);
  pthread_t ThreadId()
  {
    return m_ThreadId;
  }
  void start();
  void shutdown()
  {
    m_KeepRunning = false;
  }
  // the next function, I believe, doesn't ever return. The return statement is here to shut up the compiler warnings.
  static void *thread_entry_point(void *st)
  {
    ((supervisor_thread_t *)st)->thread_entry_point();
    return 0;
  }
  /// Pointer to the interrupt field that is the exception flag
  struct atomic_field *m_Interrupt;
  /// Pointer to the atomic field that is the exception flag
  struct atomic_field *m_Exception;
  /// Accessor for m_LocalThreadId
  int localThreadId()
  {
    return m_LocalThreadId;
  }

protected:
  void thread_entry_point();
  /// The POSIX thread Id for this thread.
  pthread_t m_ThreadId;
  /// Should the thread keep running
  volatile bool m_KeepRunning;
  /// Sequential ID of the supervisor thread assigned by supervisor during creation.
  const int m_LocalThreadId;
  // to prevent GC
  void **m_ThreadLocal;
};

#define GETSPECIFICTHREADLOCAL
// singleton -- not garbage collected
struct ThreadSupervisor {
#ifdef GETSPECIFICTHREADLOCAL
  pthread_key_t m_ThreadSpecificKey;
  static const int s_MaxThreadLocalIdCounter = 1024;
#endif
  ThreadSupervisor(int targetNumThreads);
  ~ThreadSupervisor();
  void _i_startTask(struct ThreadTask *task, struct ThreadTask *launcher);
  void _i_cancelTask(struct ThreadTask *task);
  void _i_finished(struct ThreadTask *task);
  struct ThreadTask *getTask();
  /// Target number of threads to have running at once.
  int m_TargetNumThreads;
  /// map between pthread id's and thread information structures
  std::map<pthread_t,
           struct ThreadSupervisorInformation *,
           ::std::less<>,
           ::cgc1::gc_allocator_t<::std::pair<pthread_t, struct ThreadSupervisorInformation *>>>
      m_ThreadMap;
  /// list of ready to go tasks
  std::list<ThreadTask *, ::cgc1::gc_allocator_t<ThreadTask *>> m_ReadyTasks;
  /// list of running tasks
  std::vector<ThreadTask *, ::cgc1::gc_allocator_t<ThreadTask *>> m_RunningTasks;
  /// list of tasks waiting for dependencies
  std::list<ThreadTask *, ::cgc1::gc_allocator_t<ThreadTask *>> m_WaitingTasks;
  /// list of tasks that are finished
  std::list<ThreadTask *, ::cgc1::gc_allocator_t<ThreadTask *>> m_FinishedTasks;
  /// list of canceled
  std::list<ThreadTask *, ::cgc1::gc_allocator_t<ThreadTask *>> m_CanceledTasks;
  /// mutex for accessing lists
  pthreadMutex m_Mutex;
  /// new task waiting
  pthread_cond_t m_TaskWaitingCondition;
  /// list of supervisor threads
  std::list<supervisor_thread_t *, ::cgc1::gc_allocator_t<supervisor_thread_t *>> m_Threads;
  /// set of initialized pointers
  std::set<int *, ::std::less<>, ::cgc1::gc_allocator_t<int *>> m_ThreadLocalIdPtrSet;
  /// initialize
  void initialize();
  /// thread local id's
  int m_ThreadLocalIdCounter;
  void *m_LocalThreadMemory;
};

#include "supervisorinterface.h"

#endif
