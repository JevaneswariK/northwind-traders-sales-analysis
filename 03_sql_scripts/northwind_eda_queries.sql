use northwind_datset;
-- 1.What is the average number of orders per customer? 

select avg(orders_placed) Average_Orders_Per_Customer from(
select CustomerID,COUNT(DISTINCT OrderID) orders_placed
from orders
group by CustomerID) s;

-- Are there high-value repeat customers?(Assume,threshold as (total_spend>=5000) and (totalcount>=10)

select count(*) CountOfHighValueCustomers from(
select o.CustomerID,count( distinct od.OrderID) totalcount,
sum(od.Quantity*od.UnitPrice*(1-od.Discount)) total_spend
from orders o 
join order_details od 
on o.OrderID = od.OrderID 
group by CustomerID
having totalcount>=10 
and total_spend>=5000) s ;

-- 2.How do customer order patterns vary by city or country?

select Country,City,avg(TotalCount) AverageOrdersPerCustomer 
from (select c.CustomerID,c.Country,c.City,count(o.OrderID) TotalCount 
from customers c 
join orders o 
on c.CustomerID = o.CustomerID 
group by o.CustomerID,c.Country,c.City )t
group by Country,City 
order by AverageOrdersPerCustomer desc;

-- 3.Can we cluster customers based on total spend, order count, and preferred categories?

with customer_sales as (
select c.CustomerID,sum(o.UnitPrice*o.Quantity*(1-o.Discount)) as totalSpend,
count(DISTINCT o.OrderID) totalOrders
from customers c 
join orders od
on c.CustomerID = od.CustomerID
join order_details o 
on od.OrderID = o.OrderID 
group by c.CustomerID),
customer_category as (
select cu.CustomerID,c.CategoryName,
count(DISTINCT od.OrderID) totalOrders,
sum(o.Quantity*o.UnitPrice*(1-o.Discount)) totalSpend,
row_number() over(partition by cu.CustomerID
order by count(DISTINCT od.OrderID) desc) ranking
from customers cu
join orders od
on cu.CustomerID = od.CustomerID
join order_details o 
on od.OrderID =o.OrderID
join products p 
on o.ProductID= p.ProductID 
join categories c 
on p.CategoryID = c.CategoryID
group by c.CategoryName,od.CustomerID) 
select cs.CustomerID,cc.CategoryName,cs.totalOrders,cs.totalSpend 
from customer_sales cs 
join customer_category cc
on cs.CustomerID = cc.CustomerID
AND cc.ranking = 1
order by totalOrders desc;

-- 4.Which product categories or products contribute most to order revenue? 

select c.CategoryName,count(distinct od.OrderID) TotalOrder,
sum(od.Quantity)  QuantitySold,
round(sum(od.Quantity*od.UnitPrice*(1-od.Discount)),2) TotalRevenue
from categories c
join products p
on c.CategoryID = p.CategoryID 
join order_details od 
on od.ProductID = p.ProductID 
join orders o 
on od.OrderID = o.OrderID 
join customers cu
on o.CustomerID = cu.CustomerID
group by c.CategoryName
order by TotalRevenue desc;

-- 5.Are there any correlations between orders and customer location or product category?

Select c.Country,cs.CategoryName,count(distinct o.OrderID) TotalOrder,
sum(od.Quantity) QuantitySold ,round(sum(od.Quantity*od.UnitPrice*(1-od.Discount)),2)
TotalRevenue
from customers c
join orders o 
on c.CustomerID = o.CustomerID
join order_details od 
on o.OrderID = od.OrderID
join products p 
on od.ProductID = p.ProductID 
join categories cs 
on p.CategoryID = cs.CategoryID
group by c.Country,cs.CategoryName
order by TotalRevenue desc;

-- 6.How frequently do different customer segments place orders?

select CustomerID,count(OrderID) TotalOrders,case
when count(OrderID) < 5 then 'Occasional'
when count(OrderID) between 5 and 10 then 'Regular'
else 'Frequent'
end CustomerSegment 
from orders 
group by CustomerID
order by CustomerID;

-- 7.What is the geographic and title-wise distribution of employees?

select Title,Country,count(distinct EmployeeID) EmployeeCount
from employees 
group by Title,Country; 

-- 8.What trends can we observe in hire dates across employee titles?

select year(HireDate) HireDate,Title,Country,count(EmployeeID) EmployeeHired
from employees
group by year(HireDate),Title,Country;

-- 9.What patterns exist in employee title and courtesy title distributions?

select Title,TitleOfCourtesy,count(distinct EmployeeID) EmployeeCount
from employees
group by Title,TitleOfCourtesy
order by EmployeeCount desc;

-- 10.Are there correlations between product pricing, stock levels, and sales performance?

select count(p.ProductID) TotalProducts,avg(p.UnitsInStock) AvgUnitInStocks,
sum(od.Quantity) UnitSold,avg(p.UnitPrice) AvgUnitPrice,case
when p.UnitPrice < 30 then 'LowPrice'
when p.UnitPrice between 30 and 50 then 'MediumPrice'
else 'HighPrice'
end as PriceBand
from products p 
left join order_details od 
on p.ProductID = od.ProductID 
group by 
case
when p.UnitPrice < 30 then 'LowPrice'
when p.UnitPrice between 30 and 50 then 'MediumPrice'
else 'HighPrice'
end ;

-- 11.How does product demand change over months or seasons?

select p.ProductName,
Sum(od.Quantity) ProductSold,
case
when month(o.OrderDate) in (6,7,8) then "Summer"
when month(o.OrderDate) in (9,10,11) then "Autumn"
when month(o.OrderDate) in (12,1,2) then "Winter"
else "Spring"
end as Seasons
from products p 
join order_details od 
on p.ProductID = od.ProductID 
join orders o 
on o.OrderID = od.OrderID 
group by p.ProductName,
case
when month(o.OrderDate) in (6,7,8) then "Summer"
when month(o.OrderDate) in (9,10,11) then "Autumn"
when month(o.OrderDate) in (12,1,2) then "Winter"
else "Spring"
end;

-- 12.Can we identify anomalies in product sales or revenue performance?

with monthly_Sales as (select year(o.OrderDate) Year,
month(o.OrderDate) Month,p.ProductID,sum(od.Quantity) ProductSold
from products p
join order_details od 
on p.ProductID = od.ProductID 
join orders o 
on od.OrderID = o.OrderID
group by p.ProductID,Year,Month) ,
stat as (select ProductID,avg(ProductSold) AvgSales,STDDEV(ProductSold) STD_Sales
from monthly_Sales
group by ProductID)
select m.ProductID,m.Year,m.Month,m.ProductSold,
case 
when m.ProductSold>s.AvgSales + 1*(STD_Sales) then "Spike"
when m.ProductSold<s.AvgSales - 1*(STD_Sales) then "Drop"
else "Normal"
end as Anomalies
from monthly_Sales m
join stat s 
on m.ProductID = s.ProductID
order by m.ProductID,m.Year,m.Month,m.ProductSold;

-- 13.Are there any regional trends in supplier distribution and pricing?

select s.Country,count(distinct s.SupplierID) CountOfSuppliers,
round(avg(od.UnitPrice),2) AveragePrice
from suppliers s 
join products p
on s.SupplierID = p.SupplierID
join order_details od 
on p.ProductID = od.ProductID
join orders o 
on od.OrderID = o.OrderID
group by s.Country
order by Country;

-- 14.How are suppliers distributed across different product categories?

select c.CategoryName,count(distinct s.SupplierID) SupplierCount,
count(distinct p.ProductID)  ProductCount
from suppliers s 
join products p 
on s.SupplierID = p.SupplierID
join categories c
on p.CategoryID = c.CategoryID
group by c.CategoryName
order by CategoryName;

-- 15.How do supplier pricing and categories relate across different regions?

select s.Country,c.CategoryName,
count(distinct s.SupplierID) CountOfSupplier,
round(avg(od.UnitPrice),2) AveragePrice
from suppliers s 
join products p 
on s.SupplierID = p.SupplierID 
join order_details od 
on p.ProductID = od.ProductID 
join categories c 
on p.CategoryID = c.CategoryID
group by c.CategoryName,s.Country
order by Country;

