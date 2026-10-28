#include <boost/container_hash/hash.hpp>
#include <boost/numeric/conversion/cast.hpp>
#include <boost/random/mersenne_twister.hpp>

int main() {
  boost::random::mt19937 rng(1);
  return boost::hash<int>{}(boost::numeric_cast<int>(rng() % 2)) == 0 ? 1 : 0;
}
