class AvrGcc < Formula
  desc "GNU compiler collection for AVR 8-bit and 32-bit Microcontrollers"
  homepage "https://gcc.gnu.org/"
  url "https://ftpmirror.gnu.org/gnu/gcc/gcc-15.3.0/gcc-15.3.0.tar.xz"
  mirror "https://ftp.gnu.org/gnu/gcc/gcc-15.3.0/gcc-15.3.0.tar.xz"
  sha256 "fa59c1beef8995f27c4d71c1df227587189315d3e6faff1bb4306e61b0c530eb"
  license "GPL-3.0-or-later" => { with: "GCC-exception-3.1" }
  head "https://gcc.gnu.org/git/gcc.git", branch: "master"

  # Pinned to the GCC 15 series. Major bumps change AVR code generation and
  # avr-libc compatibility, so they are done by hand after testing.
  livecheck do
    url :stable
    regex(%r{href=["']?gcc[._-]v?(15(?:\.\d+)+)(?:/?["' >]|\.t)}i)
  end

  # The macOS bottles are built on systems with the CLT installed, and do not
  # work out of the box on Xcode-only systems due to an incorrect sysroot.
  pour_bottle? only_if: :clt_installed

  depends_on "gmp"
  depends_on "isl"
  depends_on "libmpc"
  depends_on "mpfr"
  depends_on "stargrid-systems/tap/avr-binutils"
  depends_on "zstd"

  on_linux do
    # See the comment in avr-binutils.
    depends_on "gpatch" => :build
    # GCC links libz via --with-system-zlib. Match avr-binutils so the
    # dependency is direct rather than inherited.
    depends_on "zlib-ng-compat"
  end

  resource "avr-libc" do
    url "https://github.com/avrdudes/avr-libc/releases/download/avr-libc-2_3_2-release/avr-libc-2.3.2.tar.bz2"
    sha256 "92eb253d30cec94f2861a82d40d0b17ad79c0d95fce32b74ffccc26a70afb150"
  end

  patch do
    on_macos do
      url "https://raw.githubusercontent.com/Homebrew/homebrew-core/6e8384b4/Patches/gcc/gcc-15.3.0.diff"
      sha256 "f4e237594326286dc163230ebec0e763a868951649fb62e3fb0ac9c1416d0cdd"
    end
  end

  # Branch from the Darwin maintainer of GCC, with a few generic fixes and
  # Apple Silicon support, located at https://github.com/iains/gcc-15-branch

  def install
    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete "LD"

    # Even when suffixes are appended, the info pages conflict when
    # install-info is run so pretend we have an outdated makeinfo
    # to prevent their build.
    ENV["gcc_cv_prog_makeinfo_modern"] = "no"

    pkgversion = "Homebrew AVR GCC #{pkg_version}"

    args = %W[
      --target=avr
      --prefix=#{prefix}
      --libdir=#{lib}/avr-gcc

      --enable-languages=c,c++

      --with-ld=#{formula_opt_bin("stargrid-systems/tap/avr-binutils")/"avr-ld"}
      --with-as=#{formula_opt_bin("stargrid-systems/tap/avr-binutils")/"avr-as"}

      --disable-nls
      --disable-libssp
      --disable-shared
      --disable-threads
      --disable-libgomp
      --disable-werror

      --with-dwarf2
      --with-avrlibc

      --with-system-zlib

      --with-pkgversion=#{pkgversion}
      --with-bugurl=https://github.com/stargrid-systems/homebrew-tap/issues
    ]

    # Avoid reference to the sed shim.
    args << "SED=/usr/bin/sed" if OS.mac?

    mkdir "build" do
      system "../configure", *args

      # Use -headerpad_max_install_names in the build, otherwise updated load
      # commands won't fit in the Mach-O header. This is needed because `gcc`
      # avoids the superenv shim.
      make_args = OS.mac? ? ["BOOT_LDFLAGS=-Wl,-headerpad_max_install_names"] : []
      system "make", *make_args

      system "make", "install"
    end

    # info and man7 files conflict with native gcc
    rm_r(info) if info.exist?
    rm_r(man7) if man7.exist?

    resource("avr-libc").stage do
      ENV.prepend_path "PATH", bin

      ENV.delete "CFLAGS"
      ENV.delete "CXXFLAGS"
      ENV.delete "LD"
      ENV.delete "CC"
      ENV.delete "CXX"

      system "./configure", "--prefix=#{prefix}", "--host=avr"
      system "make", "install"
    end
  end

  test do
    ENV.delete "CPATH"

    (testpath/"hello.c").write <<~C
      #define F_CPU 8000000UL
      #include <avr/io.h>
      #include <util/delay.h>
      int main(void) {
        DDRB |= (1 << PB0);
        while (1) {
          PORTB ^= (1 << PB0);
          _delay_ms(500);
        }
        return 0;
      }
    C

    (testpath/"modern.c").write <<~C
      #include <avr/io.h>
      int main(void) {
        PORTA.DIRSET = PIN0_bm;
        while (1) PORTA.OUTTGL = PIN0_bm;
        return 0;
      }
    C

    system bin/"avr-gcc", "-mmcu=atmega328p", "-Os", "-o", "hello.elf", "hello.c"
    system bin/"avr-gcc", "-mmcu=atmega4809", "-Os", "-o", "modern.elf", "modern.c"

    objdump = formula_opt_bin("stargrid-systems/tap/avr-binutils")/"avr-objdump"
    assert_match "file format elf32-avr", shell_output("#{objdump} -a hello.elf")

    objcopy = formula_opt_bin("stargrid-systems/tap/avr-binutils")/"avr-objcopy"
    system objcopy, "-O", "ihex", "-j", ".text", "-j", ".data", "hello.elf", "hello.hex"
    assert_match(/\A:[0-9A-F]{8}/, (testpath/"hello.hex").read)

    (testpath/"test.cpp").write "struct S { int x; }; S s; int main() { s.x = 1; return s.x; }"
    system bin/"avr-g++", "-mmcu=atmega328p", "-Os", "-o", "test.elf", "test.cpp"
  end
end
