/* Reproduces the udp_sock_errs() NULL-flow dereference in-process, so
 * tests/passt-null-flow.nix INDUCES the crash that killed a role's network
 * helper rather than asserting about it.
 *
 * udp_sock_errs() is static, so this #includes udp.c and supplies the four
 * symbols that live in passt.c -- which carries main() and is therefore not
 * linked. FLOW_SIDX_NONE makes udp_at_sidx() return NULL, and an armed
 * SO_ERROR takes the udp.c:718 flow_dbg() branch: the exact instruction that
 * faulted on the host.
 *
 * Exits 0 if udp_sock_errs() returns; dies with SIGSEGV if it does not.
 * Loopback only, no privilege, no network -- it runs in the nix sandbox.
 */
#include "udp.c"
#include <poll.h>

/* Symbols that live in passt.c, which carries main() and so is not linked. */
char pkt_buf[PKT_BUF_BYTES] __attribute__ ((aligned(PAGE_SIZE)));
char *epoll_type_str[EPOLL_NUM_TYPES];
struct ctx passt_ctx;
void proto_update_l2_buf(const unsigned char *eth_d) { (void)eth_d; }

int main(void)
{
	struct ctx c = { 0 };
	struct timespec now = { 0 };
	struct sockaddr_in sa = {
		.sin_family = AF_INET,
		.sin_port = htons(1),			/* nothing listens */
		.sin_addr = { .s_addr = htonl(INADDR_LOOPBACK) },
	};
	int s, err = 0, i;
	socklen_t elen = sizeof(err);

	s = socket(AF_INET, SOCK_DGRAM, 0);
	if (s < 0)
		return 99;
	if (connect(s, (struct sockaddr *)&sa, sizeof(sa)) < 0)
		return 98;
	if (send(s, "x", 1, 0) < 0)
		return 97;

	/* Wait for the loopback ICMP port-unreachable to land in SO_ERROR,
	 * WITHOUT consuming it: peek by polling, then re-arm by sending again. */
	for (i = 0; i < 200; i++) {
		struct pollfd p = { .fd = s, .events = POLLERR };

		poll(&p, 1, 10);
		if (p.revents & POLLERR)
			break;
		if (send(s, "x", 1, 0) < 0)
			break;
	}

	if (getsockopt(s, SOL_SOCKET, SO_ERROR, &err, &elen) < 0 || !err) {
		fprintf(stderr, "could not arm SO_ERROR (err=%d)\n", err);
		return 96;
	}
	fprintf(stderr, "armed SO_ERROR=%d, re-arming and calling udp_sock_errs()\n", err);
	/* getsockopt above CLEARED it; put it back. */
	if (send(s, "x", 1, 0) < 0)
		return 95;
	for (i = 0; i < 200; i++) {
		struct pollfd p = { .fd = s, .events = POLLERR };

		poll(&p, 1, 10);
		if (p.revents & POLLERR)
			break;
	}

	udp_sock_errs(&c, s, FLOW_SIDX_NONE, PIF_HOST, 1, &now);
	fprintf(stderr, "survived\n");
	return 0;
}
