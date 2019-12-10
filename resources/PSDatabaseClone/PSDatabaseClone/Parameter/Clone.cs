using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PSDatabaseClone
{
    namespace Parameter
    {
        public class Clone
        {
            public int CloneID { get; set; }

            public string CloneLocation { get; set; }

            public string AccessPath { get; set; }

            public string SqlInstance { get; set; }

            public string DatabaseName { get; set; }

            public bool IsEnabled { get; set; }

            public int ImageID { get; set; }

            public string ImageName { get; set; }

            public string ImageLocation { get; set; }

            public string HostName { get; set; }
        }
    }
}
