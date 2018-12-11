using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PSDatabaseClone
{
    namespace Parameter
    {
        public class Image
        {
            public int ImageID { get; set; }

            public string ImageName { get; set; }

            public string ImageLocation { get; set; }

            public int SizeMB { get; set; }

            public string DatabaseName { get; set; }

            public DateTime DatabaseTimestamp { get; set; }

            public DateTime CreatedOn { get; set; }
        }
    }
}
