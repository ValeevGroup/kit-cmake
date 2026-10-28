#include <boost/archive/text_oarchive.hpp>
#include <boost/container_hash/hash.hpp>
#include <boost/filesystem/path.hpp>
#include <boost/random/mersenne_twister.hpp>
#include <boost/spirit/home/x3.hpp>

#include <sstream>
#include <string>

int main() {
  namespace x3 = boost::spirit::x3;
  std::string in = "42";
  int value = 0;
  auto it = in.begin();
  bool ok = x3::parse(it, in.end(), x3::int_, value) && value == 42;
  boost::random::mt19937 rng(1);
  std::ostringstream os;
  {
    boost::archive::text_oarchive ar(os);
    ar << value;
  }
  boost::filesystem::path p("a/b");
  return ok && rng() != 0 && !os.str().empty() && p.filename() == "b" &&
                 boost::hash<std::string>{}(in) != 0
             ? 0
             : 1;
}
