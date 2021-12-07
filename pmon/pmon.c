/* This file is based on pmon.c which was licensed under the GPL v2 (http://www.gnu.org/licenses/gpl2.txt) (some parts was originally borrowed from proc events example)

   It has been modified to print only fork/exec and  their associated /proc/<pid>/cmdline and /proc/<pid>/environ
   pmon.c

   changed by  Bordes 12/08/19

   NOTE: This script must be run as ROOT user
*/

#define _XOPEN_SOURCE 700
#include <sys/socket.h>
#include <linux/netlink.h>
#include <linux/connector.h>
#include <linux/cn_proc.h>
#include <signal.h>
#include <errno.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>

#define LINE_SEP "~~~~~~~~~~"
/*
 * connect to netlink
 * returns netlink socket, or -1 on error
 */
static int nl_connect()
{
	int rc;
	int nl_sock;
	struct sockaddr_nl sa_nl;

	nl_sock = socket(PF_NETLINK, SOCK_DGRAM, NETLINK_CONNECTOR);
	if (nl_sock == -1) {
		perror("socket");
		return -1;
	}

	sa_nl.nl_family = AF_NETLINK;
	sa_nl.nl_groups = CN_IDX_PROC;
	sa_nl.nl_pid = getpid();

	rc = bind(nl_sock, (struct sockaddr *)&sa_nl, sizeof(sa_nl));
	if (rc == -1) {
		perror("bind");
		close(nl_sock);
		return -1;
	}

	return nl_sock;
}

/*
 * subscribe on proc events (process notifications)
 */
static int set_proc_ev_listen(int nl_sock, bool enable)
{
	int rc;
	struct __attribute__ ((aligned(NLMSG_ALIGNTO))) {
		struct nlmsghdr nl_hdr;
		struct __attribute__ ((__packed__)) {
			struct cn_msg cn_msg;
			enum proc_cn_mcast_op cn_mcast;
		};
	} nlcn_msg;

	memset(&nlcn_msg, 0, sizeof(nlcn_msg));
	nlcn_msg.nl_hdr.nlmsg_len = sizeof(nlcn_msg);
	nlcn_msg.nl_hdr.nlmsg_pid = getpid();
	nlcn_msg.nl_hdr.nlmsg_type = NLMSG_DONE;

	nlcn_msg.cn_msg.id.idx = CN_IDX_PROC;
	nlcn_msg.cn_msg.id.val = CN_VAL_PROC;
	nlcn_msg.cn_msg.len = sizeof(enum proc_cn_mcast_op);

	nlcn_msg.cn_mcast = enable ? PROC_CN_MCAST_LISTEN : PROC_CN_MCAST_IGNORE;

	rc = send(nl_sock, &nlcn_msg, sizeof(nlcn_msg), 0);
	if (rc == -1) {
		perror("netlink send");
		return -1;
	}

	return 0;
}

struct stat *buf;

/*
 * handle a single process event
 */
static volatile bool need_exit = false;
static int handle_proc_ev(int nl_sock)
{
	char s_env[64000];
	char a_str[128];
	int rc;
	int len;

#define MAX_SBUF 64000
	char s_buf[MAX_SBUF];

	struct __attribute__ ((aligned(NLMSG_ALIGNTO))) {
		struct nlmsghdr nl_hdr;
		struct __attribute__ ((__packed__)) {
			struct cn_msg cn_msg;
			struct proc_event proc_ev;
		};
	} nlcn_msg;

	int fd,mypid;
	while (!need_exit) {
		rc = recv(nl_sock, &nlcn_msg, sizeof(nlcn_msg), 0);
		if (rc == 0) {
			/* shutdown? */
			return 0;
		} else if (rc == -1) {
			if (errno == EINTR) continue;
			perror("netlink recv");
			// return -1;
		}
		switch (nlcn_msg.proc_ev.what) {
		case PROC_EVENT_NONE:
			printf("set mcast listen ok\n");
			break;
		case PROC_EVENT_FORK:
		case PROC_EVENT_EXEC:
			if (nlcn_msg.proc_ev.what == PROC_EVENT_FORK)
				mypid = nlcn_msg.proc_ev.event_data.fork.child_pid;
			else
				mypid = nlcn_msg.proc_ev.event_data.exec.process_pid;

			if (mypid)
			{
				sprintf(a_str, LINE_SEP "\npid=%d\n",mypid);
				write(STDOUT_FILENO, a_str, strlen(a_str));
				sprintf (a_str,"/proc/%d/cmdline", mypid);
				if ((fd=open(a_str, O_RDONLY)) != -1) {
					write (STDOUT_FILENO, LINE_SEP, sizeof(LINE_SEP));
					s_buf[0] = 0;
					len = read(fd, s_buf,MAX_SBUF);
					write (STDOUT_FILENO, s_buf, len);
					write (STDOUT_FILENO, "\n", 1);
					close(fd);
				}
				sprintf (a_str,"/proc/%d/environ", mypid);
				if ((fd=open(a_str, O_RDONLY)) != -1) {
					write (STDOUT_FILENO, LINE_SEP, sizeof(LINE_SEP));
					s_buf[0] = 0;
					len = read(fd, s_buf,MAX_SBUF);
					write (STDOUT_FILENO, s_buf, len);
					write (STDOUT_FILENO, "\n", 1);
					close(fd);
				}
			}
#if 0
			printf("fork: parent tid=%d pid=%d -> child tid=%d pid=%d\n",
			       nlcn_msg.proc_ev.event_data.fork.parent_pid,
			       nlcn_msg.proc_ev.event_data.fork.parent_tgid,
			       nlcn_msg.proc_ev.event_data.fork.child_pid,
			       nlcn_msg.proc_ev.event_data.fork.child_tgid);
#endif
			break;
#if 0
		case PROC_EVENT_EXEC:
			sprintf (a_str,"/proc/%d/cmdline", nlcn_msg.proc_ev.event_data.exec.process_pid);
			if ((fd=open(a_str, O_RDONLY)) != -1)
			{
				close(fd);
				printf("exec: tid=%d pid=%d\n",
				       nlcn_msg.proc_ev.event_data.exec.process_pid,
				       nlcn_msg.proc_ev.event_data.exec.process_tgid);
				sprintf (s_env,"echo %%%%%  ; cat /proc/%d/cmdline", nlcn_msg.proc_ev.event_data.fork.child_tgid);
				system (s_env);
				sprintf (s_env,"echo ; echo %%%%% ; cat /proc/%d/environ", nlcn_msg.proc_ev.event_data.fork.child_tgid);
				system (s_env);
			}
			else
				printf ("File:%s errno=%d\n", a_str, errno);
			break;
#endif
#if 0
		case PROC_EVENT_UID:
			printf("uid change: tid=%d pid=%d from %d to %d\n",
			       nlcn_msg.proc_ev.event_data.id.process_pid,
			       nlcn_msg.proc_ev.event_data.id.process_tgid,
			       nlcn_msg.proc_ev.event_data.id.r.ruid,
			       nlcn_msg.proc_ev.event_data.id.e.euid);
			break;
		case PROC_EVENT_GID:
			printf("gid change: tid=%d pid=%d from %d to %d\n",
			       nlcn_msg.proc_ev.event_data.id.process_pid,
			       nlcn_msg.proc_ev.event_data.id.process_tgid,
			       nlcn_msg.proc_ev.event_data.id.r.rgid,
			       nlcn_msg.proc_ev.event_data.id.e.egid);
			break;
		case PROC_EVENT_EXIT:
			printf("exit: tid=%d pid=%d exit_code=%d\n",
			       nlcn_msg.proc_ev.event_data.exit.process_pid,
			       nlcn_msg.proc_ev.event_data.exit.process_tgid,
			       nlcn_msg.proc_ev.event_data.exit.exit_code);
			break;
#endif
		default:
			//        printf("unhandled proc event\n");
			break;
		}
	}

	return 0;
}

static void on_sigint(int unused)
{
	need_exit = true;
}

int main(int argc, const char *argv[])
{
	int nl_sock;
	int rc = EXIT_SUCCESS;

	signal(SIGINT, &on_sigint);
	siginterrupt(SIGINT, true);

	nl_sock = nl_connect();
	if (nl_sock == -1)
		exit(EXIT_FAILURE);

	rc = set_proc_ev_listen(nl_sock, true);
	if (rc == -1) {
		rc = EXIT_FAILURE;
		goto out;
	}

	rc = handle_proc_ev(nl_sock);
	if (rc == -1) {
		rc = EXIT_FAILURE;
		goto out;
	}

	set_proc_ev_listen(nl_sock, false);

out:
	close(nl_sock);
	exit(rc);
}

