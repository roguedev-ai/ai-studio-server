'use client';

import { InboxOutlined } from '@ant-design/icons';
import { message, Upload, Card, Progress, List } from 'antd';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';

type FileItem = {
  uid: string;
  name: string;
  status: 'uploading' | 'done' | 'error';
  size: number;
  type: string;
  percent?: number;
};

interface DocumentUploaderProps {
  collectionName: string;
  onDocumentProcessed: (documents: any[]) => void;
}

export default function DocumentUploader({
  collectionName,
  onDocumentProcessed
}: DocumentUploaderProps) {
  const { t } = useTranslation();
  const [fileList, setFileList] = useState<FileItem[]>([]);

  const { Dragger } = Upload;

  const uploadProps = {
    name: 'document',
    multiple: true,
    accept: '.pdf,.docx,.txt,.md,.xlsx,.xls,.pptx,.ppt',
    beforeUpload: (file: File) => {
      const isValidType =
        file.type === 'application/pdf' ||
        file.type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
        file.type === 'text/plain' ||
        file.type === 'text/markdown' ||
        file.type === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        file.type === 'application/vnd.ms-excel' ||
        file.type === 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
        file.type === 'application/vnd.ms-powerpoint';

      if (!isValidType) {
        message.error(`${file.name}: Invalid file type. Please upload a supported document format.`);
        return Upload.LIST_IGNORE;
      }

      const isLt50M = file.size / 1024 / 1024 < 50;
      if (!isLt50M) {
        message.error(`${file.name}: File size exceeds 50MB limit.`);
        return Upload.LIST_IGNORE;
      }

      return true;
    },
    customRequest: async (options: any) => {
      const { file, onSuccess, onError, onProgress } = options;

      // Simulate upload progress
      let percent = 0;
      const interval = setInterval(() => {
        percent += 10;
        if (percent >= 100) {
          clearInterval(interval);
          percent = 100;
        }
        onProgress({ percent });
      }, 200);

      try {
        // Here we would call the document processing API
        // For now, simulate processing
        const result = await mockDocumentProcessing(file);

        clearInterval(interval);
        onSuccess(result, file);
        message.success(`${file.name} processed successfully`);
      } catch (error) {
        clearInterval(interval);
        onError({ error: new Error('Upload failed') });
        message.error(`${file.name} processing failed: ${error.message}`);
      }
    },
    onChange: ({ file, fileList: newFileList }) => {
      setFileList(newFileList);
    },
    onRemove: (file: FileItem) => {
      setFileList(prev => prev.filter(f => f.uid !== file.uid));
    }
  };

  // Mock document processing for now
  const mockDocumentProcessing = async (file: File): Promise<any> => {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          filename: file.name,
          size: file.size,
          type: file.type,
          chunks: 5,
          status: 'processed',
          collection: collectionName
        });
      }, 2000);
    });
  };

  return (
    <Card title={t('Knowledge Base Management')} style={{ marginBottom: 16 }}>
      <Dragger {...uploadProps}>
        <p className="ant-upload-drag-icon">
          <InboxOutlined />
        </p>
        <p className="ant-upload-text">
          {t('Click or drag documents to upload')}
        </p>
        <p className="ant-upload-hint">
          {t('Supports PDF, Word, Excel, PowerPoint, and text files up to 50MB')}
        </p>
      </Dragger>

      {fileList.length > 0 && (
        <List
          size="small"
          dataSource={fileList}
          renderItem={(file) => (
            <List.Item>
              <div style={{ display: 'flex', alignItems: 'center', width: '100%' }}>
                <div style={{ flex: 1 }}>
                  <span>{file.name}</span>
                  <span style={{ marginLeft: 8, color: '#666' }}>
                    ({(file.size / 1024 / 1024).toFixed(2)} MB)
                  </span>
                </div>
                <div style={{ marginLeft: 16, minWidth: 100 }}>
                  {file.status === 'uploading' && file.percent && (
                    <Progress percent={file.percent} size="small" status="active" />
                  )}
                  {file.status === 'done' && (
                    <span style={{ color: 'green' }}>✓ Processed</span>
                  )}
                  {file.status === 'error' && (
                    <span style={{ color: 'red' }}>✗ Failed</span>
                  )}
                </div>
              </div>
            </List.Item>
          )}
        />
      )}
    </Card>
  );
}
