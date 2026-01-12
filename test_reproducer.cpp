#include <rmm/device_vector.hpp>

int main(void)
{
   rmm::device_vector<double> vector(10);
   return 0;
}

