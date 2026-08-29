class Simavr < Formula
  desc "Lean, mean and hackable AVR simulator"
  homepage "https://github.com/buserror/simavr"
  url "https://github.com/buserror/simavr/archive/refs/tags/v1.8.tar.gz"
  sha256 "51e2682d23fb4843191ee81dadcb5488fa6194553a108bbd6e60e8b1260269d6"
  license "GPL-3.0-or-later"
  head "https://github.com/buserror/simavr.git", branch: "master"

  # Upstream tags releases but does not publish GitHub releases.
  livecheck do
    url :head
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "pkgconf" => :build
  depends_on "stargrid-systems/tap/avr-gcc"

  on_macos do
    depends_on "libelf"
  end

  on_linux do
    # Homebrew's libelf is macOS-only. elfutils provides libelf.pc on Linux.
    depends_on "elfutils"
  end

  def install
    ENV.deparallelize

    make_args = ["HOMEBREW_PREFIX=#{HOMEBREW_PREFIX}", "RELEASE=1"]
    # Only build the simulator. build-parts needs GLUT, and build-examples
    # produces AVR firmware that `brew audit` rejects as non-native.
    system "make", "build-simavr", *make_args
    system "make", "install-simavr", "DESTDIR=#{prefix}", *make_args

    # Example sources only. Build them in place with `make`. The upstream
    # tree also checks in prebuilt AVR firmware, which `brew audit` rejects.
    rm(Dir["examples/**/*.{elf,axf,hex}"])
    pkgshare.install "examples"
  end

  test do
    # Stop the AVR compiler picking up the host SDK headers.
    ENV.delete "CPATH"

    (testpath/"blink.c").write <<~C
      #include <avr/io.h>
      int main(void) {
        DDRB |= (1 << PB0);
        while (1) PORTB ^= (1 << PB0);
        return 0;
      }
    C

    system formula_opt_bin("stargrid-systems/tap/avr-gcc")/"avr-gcc", "-mmcu=atmega328p", "-Os",
           "-o", "blink.elf", "blink.c"
    # --list-cores exits 1 after printing the list.
    assert_match "atmega328p", shell_output("#{bin}/simavr --list-cores 2>&1", 1)
  end
end
