// neg-05: OrderService — Application service in Services/ path (not Domain/Entities/ or Configurations/)
// Expected: NO signal for any check:
//   CHECK 1: find -path "*/Domain/Entities/*.cs" → Services/*.cs not matched → never scanned
//   CHECK 2: find -path "*/Configurations/*.cs" → Services/*.cs not matched → never scanned
//   CHECK 3: grep AlterColumn.*maxLength → no such pattern in this file → no match
using System;
using System.Threading.Tasks;

namespace MyApp.Application.Services
{
    public class OrderService
    {
        private readonly IOrderRepository _repository;
        private readonly ICustomerRepository _customerRepository;

        public OrderService(IOrderRepository repository, ICustomerRepository customerRepository)
        {
            _repository = repository;
            _customerRepository = customerRepository;
        }

        public async Task<OrderDto> CreateOrderAsync(CreateOrderRequest request)
        {
            var customer = await _customerRepository.GetByIdAsync(request.CustomerId);
            if (customer == null)
                throw new NotFoundException("Customer not found");

            var order = OrderEntity.Create(request.CustomerId, request.Description, request.TotalAmount);
            await _repository.AddAsync(order);
            return new OrderDto(order);
        }
    }
}
