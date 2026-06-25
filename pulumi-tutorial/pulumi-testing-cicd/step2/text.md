# 修复程序让测试通过

现在只做最小修改：给 S3 Bucket 补齐 owner 与 managedBy 标签。

```bash
cd /root/workspace && \
cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as s3 from "@pulumi/aws/s3";
import { Provider } from "@pulumi/aws/provider";

const config = new pulumi.Config();
const prefix = config.get("prefix") ?? "testing";

const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});

export const bucket = new s3.Bucket("artifact-bucket", {
  bucket: `${prefix}-artifact-bucket`,
  forceDestroy: true,
  tags: {
    environment: "dev",
    owner: "platform-team",
    managedBy: "pulumi",
  },
}, { provider: localAws });

export const bucketName = bucket.bucket;
export const bucketArn = bucket.arn;
TS
```{{exec}}

重新运行单元测试。绿色结果说明资源输入已经满足测试写下的约束。

```bash
cd /root/workspace && \
npm run test:unit
```{{exec}}

再看一次 preview。单元测试不需要 Pulumi CLI，但 preview 会执行真实 Pulumi 入口，并通过 AWS provider 对接 MiniStack。

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview
```{{exec}}